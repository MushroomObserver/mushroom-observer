# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
# Actions
# -------
# new (get)
# create (post)
# authorization_response (get)
# cancel (put)
#
# Work flow:
# 1. User calls `new`, fills out form; creates an InatImport record
# 2. create: saves inat_ids/inat_url/username, redirects to iNat OAuth
# 3. iNat: checks authorization, calls back to authorization_response
# 4. authorization_response:
#      Updates state to Authenticating, enqueues InatImportJob,
#      redirects to show. The show page subscribes to a Turbo Stream
#      channel ([user, :inat_import]) that broadcasts status updates
#      whenever the InatImport record changes.
# 5. InatImportJob:
#      Authenticates, imports observations, updates InatImport state.
#      Each update triggers an after_update_commit broadcast that
#      replaces the status panel on the show page via Turbo Stream.
#
class InatImportsController < ApplicationController
  include Validators
  include Estimators
  include FormBuilders
  include Inat::Constants

  before_action :login_required
  before_action :flatten_confirm_params, only: :create
  before_action :flatten_new_form_params, only: :create

  def index
    admin = in_admin_mode? == true
    scope = admin ? InatImport.all : InatImport.where(user: @user)
    imports = scope.order(updated_at: :desc).to_a
    render(Views::Controllers::InatImports::Index.new(
             imports: imports,
             admin: admin,
             result_import_ids: import_ids_with_results(imports)
           ))
  end

  # Ids of the imports that actually have linked observations. Historic
  # imports predate the observations.inat_import_id link, so their Results
  # link would lead nowhere; the index hides it for them. One query, to
  # avoid an N+1 across the (unpaginated) admin list.
  def import_ids_with_results(imports)
    Observation.where(inat_import_id: imports.map(&:id)).
      distinct.pluck(:inat_import_id)
  end
  private :import_ids_with_results

  def results
    @inat_import = InatImport.find(params[:id])
    query = Query.lookup(:Observation, inat_import: @inat_import)
    redirect_with_query(observations_path, query)
  end

  def show
    @inat_import = InatImport.find(params[:id])
    respond_to do |format|
      format.html do
        render(Views::Controllers::InatImports::Show.new(
                 inat_import: @inat_import, user: @user
               ))
      end
      format.turbo_stream do
        html = render_to_string(
          Views::Controllers::InatImports::Status.new(
            inat_import: @inat_import
          ),
          layout: false
        )
        render(turbo_stream: turbo_stream.replace(
          "inat_import_#{@inat_import.id}", html: html
        ))
      end
    end
  end

  def new
    @inat_import = InatImport.find_or_create_by(user: @user)
    return render_new_form unless @inat_import.job_pending?

    flash_warning(:inat_import_tracker_pending.l)
    redirect_to(inat_import_path(@inat_import))
  end

  def create
    return reload_form if params[:go_back] == "1"
    return reload_form unless params_valid?

    normalize_inat_ids_param!
    normalize_inat_url_param!
    return confirm_import unless params[:confirmed] == "1"

    warn_about_listed_previous_imports
    assure_user_has_inat_import_api_key
    init_ivars
    request_inat_user_authorization
  end

  private

  def confirm_import
    @expected = fetch_expected_count
    return inat_unreachable if @expected.nil?
    return reload_form if @expected == false

    @unlicensed_obs = if import_others?
                        fetch_unlicensed_others_count
                      else
                        fetch_unlicensed_obs_count
                      end
    @inat_import = InatImport.find_or_create_by(user: @user)
    warn_about_listed_previous_imports
    @confirm_form = build_confirm_form
    render(Views::Controllers::InatImports::Confirm.new(
             confirm_form: @confirm_form,
             expected: @expected,
             unlicensed_obs: @unlicensed_obs,
             inat_import: @inat_import,
             **fetch_confirm_counts
           ))
  end

  def fetch_confirm_counts
    {
      requested: fetch_raw_requested_count,
      after_taxon: fetch_after_taxon_count,
      estimate_with_date: fetch_estimate_with_date_count
    }
  end

  def inat_unreachable
    flash_error(:inat_cannot_communicate.l)
    reload_form
  end

  # For storage: extract only digit tokens and join with commas.
  def normalize_inat_ids(ids)
    return nil if ids.nil?

    ids.split(/[\s,]+/).grep(/\A\d+\z/).join(",")
  end

  # Normalize params[:inat_ids] in-place once after validation so all
  # downstream readers (estimators, confirm form, init_ivars) see a
  # clean comma-separated digit-only string.
  def normalize_inat_ids_param!
    return unless listing_ids?

    params[:inat_ids] = normalize_inat_ids(params[:inat_ids])
  end

  # Normalize params[:inat_url] in-place: convert any observation search URL
  # to a cleaned query string. Saves the original so Go Back can restore it.
  def normalize_inat_url_param!
    return unless listing_url?
    return unless params[:inat_url].include?("://")

    normalizer = build_url_normalizer_with_warnings
    params[:original_inat_url] = params[:inat_url]
    params[:inat_url] = normalizer.normalize.to_s
  end

  def build_url_normalizer_with_warnings
    taxon_id_ok = url_taxon_ids_importable?
    normalizer = url_normalizer(params[:inat_url], keep_taxon_id: taxon_id_ok)
    warn_about_non_importable_taxon unless taxon_id_ok
    warn_about_ignored_url_params(normalizer)
    normalizer
  end

  def warn_about_ignored_url_params(normalizer)
    ignored = normalizer.ignored_params
    return if ignored.blank?

    flash_warning(:inat_url_params_ignored.t(params: ignored.join(", ")))
  end

  def url_normalizer(url, keep_taxon_id: false)
    Inat::URLNormalizer.new(
      url,
      superimporter: InatImport.super_importer?(@user),
      import_others: import_others?,
      keep_taxon_id: keep_taxon_id
    )
  end

  # True when every taxon_id value in the URL is a Fungi/Mycetozoa descendant,
  # or when no taxon_id is present. Result is memoized — the iNat API call
  # runs at most once per request.
  def url_taxon_ids_importable?
    unless instance_variable_defined?(:@url_taxon_ids_importable)
      ids = taxon_ids_from_url(params[:inat_url].to_s)
      @url_taxon_ids_importable =
        ids.empty? || Inat::TaxonValidator.new(ids).all_importable?
    end
    @url_taxon_ids_importable
  end

  def taxon_ids_from_url(url)
    Rack::Utils.parse_query(URI.parse(url).query.to_s)["taxon_id"].
      to_s.split(",").map(&:strip).compact_blank
  rescue URI::InvalidURIError
    []
  end

  def warn_about_non_importable_taxon
    flash_warning(:inat_taxon_id_not_importable.l)
  end

  # Were any listed iNat IDs previously imported?
  def warn_about_listed_previous_imports
    return if importing_all? || !listing_ids?

    previous_imports = previously_imported_links
    return if previous_imports.none?

    flash_warning(:inat_previous_import.t(count: previous_imports.count))
  end

  def previously_imported_links
    return ExternalLink.none if inat_id_list.blank?

    ExternalLink.import.where(target_type: "Observation",
                              external_site: inat_site,
                              external_id: inat_id_list.map(&:to_s))
  end

  def inat_site
    @inat_site ||= ExternalSite.inaturalist
  end

  def assure_user_has_inat_import_api_key
    key = APIKey.find_by(user: @user, notes: MO_API_KEY_NOTES)
    key = APIKey.create(user: @user, notes: MO_API_KEY_NOTES) if key.nil?
    key.verify! if key.verified.nil?
  end

  def init_ivars
    @inat_import = InatImport.find_or_create_by(user: @user)
    @inat_import.update(
      state: "Authorizing",
      import_all: params[:all],
      importables: importables_count,
      total_importables: importables_count,
      imported_count: 0,
      avg_import_time: @inat_import.initial_avg_import_seconds,
      inat_username: params[:inat_username]&.strip,
      inat_ids: clean_inat_ids,
      inat_url: params[:inat_url].presence,
      import_others: import_others?,
      writeback: writeback_policy,
      response_errors: "",
      token: "",
      log: [],
      ended_at: nil,
      cancel: false
    )
  end

  def importables_count
    return nil if importing_all? || listing_url?

    inat_id_list.length
  end

  # Returns whether this import covers other users' observations.
  # Always false for regular users; determined by checkbox for superimporters.
  def import_others?
    return false unless InatImport.super_importer?(@user)

    params[:import_others] == "1"
  end

  # Admins can toggle the iNat write-back per import via a form checkbox
  # (checked = skip, unchecked = force it on). Everyone else gets `default`
  # so the importer applies its environment default (skip in development,
  # write back in production).
  def writeback_policy
    return :default unless in_admin_mode?

    params[:skip_inat_writeback] == "1" ? :skip : :force
  end

  def clean_inat_ids
    inat_ids = normalize_inat_ids(params[:inat_ids])
    previous_imports = previously_imported_links
    return inat_ids if previous_imports.none?

    remove_previously_imported_ids(inat_ids, previous_imports)
  end

  # Remove previously imported ids in case the iNat user deleted the
  # Mushroom_Observer_URL field.
  # NOTE: Also useful in manual testing when writes of iNat obss are
  # commented out temporarily. jdc 2026-01-15
  def remove_previously_imported_ids(inat_ids, previous_imports)
    previous_ids = previous_imports.pluck(:external_id)
    remaining_ids =
      inat_ids.split(",").map(&:strip).reject { |id| previous_ids.include?(id) }
    remaining_ids.join(",")
  end

  def request_inat_user_authorization
    redirect_to(INAT_AUTHORIZATION_URL, allow_other_host: true)
  end

  # ---------------------------------

  public

  # iNat redirects here after user completes iNat authorization
  def authorization_response
    auth_code = params[:code]
    return not_authorized if auth_code.blank?

    inat_import = inat_import_authenticating(auth_code)
    inat_import.reset_last_obs_start

    Rails.logger.info(
      "Enqueueing InatImportJob for InatImport id: #{inat_import.id}"
    )
    InatImportJob.perform_later(inat_import)

    redirect_to(inat_import_path(inat_import))
  end

  # ---------------------------------

  private

  def not_authorized
    flash_error(:inat_no_authorization.l)
    redirect_to(observations_path)
  end

  def inat_import_authenticating(auth_code)
    inat_import = InatImport.find_or_create_by(user: @user)
    inat_import.update(token: auth_code, state: "Authenticating")
    inat_import
  end

  public

  def cancel
    @inat_import = InatImport.find(params[:id])
    @inat_import.update(cancel: true)
    redirect_to(inat_import_path(@inat_import))
  end
end
