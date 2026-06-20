# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
# Actions
# -------
# new (get)
# create (post)
# authorization_response (get)
# cancel (post):: cancels the InatImportJob
#
# Work flow:
# 1. User calls `new`, fills out form
#    Adds a InatImport instance if user lacks one
# 2. create
#    saves some user data in a InatImport instance
#      attributes include: user, inat_ids, token, state
#    passes things off (redirects) to iNat at the INAT_AUTHORIZATION_URL
# 3. iNat
#    checks if MO is authorized to access iNat user's confidential data
#      if not, asks iNat user for authorization
#    iNat calls the MO redirect_url (authorization_response) with a code param
# 4. MO continues in the authorization_response action
#    Reads the saved InatImport instance
#    Updates the InatImport instance with the code received from iNat
#    Instantiates an InatImportJobTracker, passing in the InatImport instance
#    Enqueues an InatImportJob, passing in the InatImport instance
#    Redirects to InatImport.show (for that InatImport instance)
#    ---------------------------------
#    InatImport.show view: (app/views/controllers/inat_imports/show.html.erb)
#      Includes a `#status` element which:
#        Instantiates a Stimulus controller (inat-import-job_controller)
#        with an endpoint of InatImportJobTracker.show
#        is updated by a TurboStream response from the endpoint
#    ---------------------------------
#    Stimulus controller (inat-import-job_controller):
#      Makes a request every second to the InatImportJobTracker.show endpoint
#    ---------------------------------
#    The endpoint (app/controllers/inat_imports/job_trackers_controller.rb):
#      renders the InatImport as a TurboStream response
#    ---------------------------------
# 5. The InatImportJob:
#      Uses the `code` to obtain an oauth access_token
#      Trades the oauth token for a JWT api_token
#      Checks if the MO user is trying to import someone else's observations
#      Makes an authenticated iNat API request for the desired observations
#      For each iNat obs in the results,
#         creates an Inat::Obs
#         adds an MO Observation, mapping Inat::Obs details to the MO Obs
#         adds the iNat id to the MO observation inat_id_field
#         adds a Snapshot of the iNat observation to the MO Observation notes
#         adds Inat photos to the MO Observation via the MO API
#         maps iNat sequences to MO Sequences
#         updates the iNat obs with a Mushroom Observer URL Observation Field
#         updates the iNat obs Notes
#      updates the InatImport instance attributes:
#         state, importables, imported_count, total_imported_count,
#         total_seconds, avg_import_time,response_errors
#
class InatImportsController < ApplicationController
  include Validators
  include Estimators
  include FormBuilders
  include Inat::Constants

  before_action :login_required
  before_action :flatten_confirm_params, only: :create
  before_action :flatten_new_form_params, only: :create

  def show
    @tracker = InatImportJobTracker.find(params[:tracker_id])
    @inat_import = InatImport.find(params[:id])
    render(Views::Controllers::InatImports::Show.new(
             tracker: @tracker, inat_import: @inat_import, user: @user
           ))
  end

  def new
    @inat_import = InatImport.find_or_create_by(user: @user)
    return render_new_form unless @inat_import.job_pending?

    tracker = InatImportJobTracker.where(
      inat_import: @inat_import
    ).order(:created_at).last
    flash_warning(:inat_import_tracker_pending.l)
    redirect_to(
      inat_import_path(
        @inat_import, params: { tracker_id: tracker.id }
      )
    )
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
    @estimate = fetch_import_estimate
    return inat_unreachable if @estimate.nil?

    @unlicensed_obs = if import_others?
                        fetch_unlicensed_others_count
                      else
                        fetch_unlicensed_obs_count
                      end
    warn_about_listed_previous_imports
    @inat_import = InatImport.find_or_create_by(user: @user)
    @confirm_form = build_confirm_form
    render(Views::Controllers::InatImports::Confirm.new(
             confirm_form: @confirm_form, estimate: @estimate,
             unlicensed_obs: @unlicensed_obs, inat_import: @inat_import
           ))
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

    previous_imports = previously_imported_observations
    return if previous_imports.none?

    flash_warning(:inat_previous_import.t(count: previous_imports.count))
  end

  def previously_imported_observations
    return Observation.none if inat_id_list.blank?

    Observation.where(external_source: inat_source,
                      external_id: inat_id_list.map(&:to_s))
  end

  def inat_source
    @inat_source ||= Source.inaturalist
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
    previous_imports = previously_imported_observations
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
    tracker = fresh_tracker(inat_import)

    Rails.logger.info(
      "Enqueueing InatImportJob for InatImport id: #{inat_import.id}"
    )
    # InatImportJob.perform_now(inat_import) # uncomment to manually test job
    InatImportJob.perform_later(inat_import)

    redirect_to(inat_import_path(inat_import,
                                 params: { tracker_id: tracker.id }))
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

  def fresh_tracker(inat_import)
    # clean out this user's old tracker(s)
    InatImportJobTracker.where(inat_import: inat_import.id).destroy_all
    InatImportJobTracker.create(inat_import: inat_import.id)
  end

  public

  def cancel
    @inat_import = InatImport.find(params[:id])
    @inat_import.update(cancel: true)
    @tracker = InatImportJobTracker.where(inat_import: @inat_import).
               order(:created_at).last
    render(Views::Controllers::InatImports::Show.new(
             tracker: @tracker, inat_import: @inat_import, user: @user
           ))
  end
end
