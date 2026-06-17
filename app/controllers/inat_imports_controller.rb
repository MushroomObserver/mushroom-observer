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
    return confirm_import unless params[:confirmed] == "1"

    warn_about_listed_previous_imports
    assure_user_has_inat_import_api_key
    init_ivars
    request_inat_user_authorization
  end

  # ---------------------------------

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

  def build_confirm_form
    FormObject::InatImportConfirm.new(
      inat_username: params[:inat_username],
      inat_ids: params[:inat_ids],
      import_all: params[:all],
      consent: params[:consent],
      import_others: (import_others? ? "1" : nil),
      skip_inat_writeback: params[:skip_inat_writeback]
    )
  end

  def inat_unreachable
    flash_error(:inat_cannot_communicate.l)
    reload_form
  end

  # Superform namespaces hidden fields under the model key.
  # Flatten them to top-level so the rest of the controller works unchanged.
  def flatten_confirm_params
    confirm = params[:inat_import_confirm]
    return unless confirm

    merge_form_param(confirm, :inat_username)
    merge_form_param(confirm, :inat_ids)
    merge_form_param(confirm, :consent)
    merge_form_param(confirm, :import_others)
    merge_form_param(confirm, :skip_inat_writeback)
    params[:all] ||= confirm[:import_all]
  end

  def merge_form_param(form_params, key)
    params[key] ||= form_params[key]
  end

  def reload_form
    render_new_form(submitted: {
                      username: params[:inat_username],
                      inat_ids: params[:inat_ids],
                      all: params[:all],
                      consent: params[:consent],
                      import_others: params[:import_others],
                      skip_writeback: params[:skip_inat_writeback]
                    })
  end

  def render_new_form(submitted: {})
    render(
      Views::Controllers::InatImports::New.new(
        form: build_new_form(submitted),
        super_importer: InatImport.super_importer?(@user),
        admin: in_admin_mode?
      ),
      layout: true
    )
  end

  def build_new_form(submitted)
    FormObject::InatImport.new(
      inat_username: submitted.fetch(:username, @user.inat_username),
      inat_ids: submitted[:inat_ids],
      all: ("1" if submitted[:all] == "1"),
      consent: ("1" if submitted[:consent] == "1"),
      import_others: ("1" if submitted[:import_others] == "1"),
      skip_inat_writeback: initial_skip_writeback(submitted)
    )
  end

  # The fresh form (no :skip_writeback key) pre-checks the box to mirror the
  # default that will apply if the admin doesn't touch it: skip in
  # development, write back in production. On reload, honor the submitted
  # state.
  def initial_skip_writeback(submitted)
    return ("1" if Rails.env.development?) unless
      submitted.key?(:skip_writeback)

    ("1" if submitted[:skip_writeback] == "1")
  end

  # Superform namespaces fields under the model key.
  # Flatten them to top-level so the controller works
  # unchanged.
  def flatten_new_form_params
    new_form = params[:inat_import]
    return unless new_form

    merge_form_param(new_form, :inat_username)
    merge_form_param(new_form, :inat_ids)
    merge_form_param(new_form, :consent)
    merge_form_param(new_form, :import_others)
    merge_form_param(new_form, :skip_inat_writeback)
    params[:all] ||= new_form[:all]
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
    return nil if importing_all?

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
    InatImportJob.perform_later(inat_import) # uncomment for production

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
