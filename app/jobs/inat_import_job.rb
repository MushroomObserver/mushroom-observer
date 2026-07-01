# frozen_string_literal: true

require "English"

class InatImportJob < ApplicationJob
  attr_accessor :inat_import

  include Inat::Constants

  queue_as :default

  # Maximum observations imported per job. Keeps individual jobs short
  # (~1 min at ~0.6s/obs) so SolidQueue stays responsive. When a batch
  # fills, a continuation job is enqueued automatically.
  BATCH_SIZE = 10

  delegate :canceled?, to: :inat_import
  delegate :imported_count, to: :inat_import
  delegate :inat_username, to: :inat_import
  delegate :response_errors, to: :inat_import
  delegate :token, to: :inat_import
  delegate :user, to: :inat_import

  # id_above: iNat observation ID cursor — 0 for the first job,
  #   last_import_id of the previous batch for continuations.
  # continuation: true skips auth + state init (already done by first job).
  def perform(inat_import, id_above: 0, continuation: false)
    create_ivars(inat_import)
    unless continuation
      authenticate
      ensure_not_importing_others
    end
    import_requested_observations(id_above: id_above,
                                  continuation: continuation)
  rescue StandardError => e
    log("Error occurred: #{e.message}")
    inat_import.add_response_error(e)
  # Intentional: catch non-StandardError exceptions so they are logged
  # and recorded on the import record rather than silently lost.
  rescue Exception => e # rubocop:disable Lint/RescueException
    # Re-raise shutdown signals so the worker shuts down cleanly.
    # ensure still runs during unwinding; the $ERROR_INFO check below skips
    # safe_done so the record stays Importing and the recovery job cleans it up.
    raise if non_rescuable?(e)

    log("Unexpected error: #{e.message}")
    inat_import&.add_response_error(e.message)
  ensure
    # Skip safe_done on shutdown signals: leave the record in Importing state
    # so SolidQueue can requeue the job. The recovery job will finalize it
    # if the worker is killed before the job can be retried.
    # Also skip when a continuation job was enqueued — that job calls done.
    safe_done unless non_rescuable?($ERROR_INFO) || @continuation_enqueued
  end

  private

  def create_ivars(inat_import)
    @inat_import = inat_import
    log(
      "InatImportJob #{inat_import.id} started, user: #{user.id}"
    )
  end

  def authenticate
    token_service = Inat::APIToken.new(
      app_id: APP_ID, site: SITE,
      redirect_uri: REDIRECT_URI,
      secret: APP_SECRET
    )
    token = token_service.obtain_api_token(inat_import.token)
    inat_import.update(token: token)
    log("Obtained iNat API token")
  end

  # Prevent MO users from importing other users' iNat observations,
  # unless they are super importers.
  def ensure_not_importing_others
    return log("Skipped own-obs check (SuperImporter)") if super_importer?

    begin
      # fetch the logged-in iNat user
      # https://api.inaturalist.org/v1/docs/#!/Users/get_users_me
      response = Inat::APIRequest.new(token).request(path: "users/me")
    rescue RestClient::Unauthorized, RestClient::ExceptionWithResponse => e
      raise("iNat API user request failed: #{e.message}")
    end

    inat_logged_in_user = JSON.parse(response.body)["results"].first["login"]
    log("inat_logged_in_user: #{inat_logged_in_user}")
    return if inat_logged_in_user == inat_username

    wrong_inat_user_error(inat_logged_in_user)
  end

  def super_importer?
    InatImport.super_importer?(user)
  end

  def wrong_inat_user_error(inat_logged_in_user)
    raise(:inat_wrong_user.t(inat_username: inat_username,
                             inat_logged_in_user: inat_logged_in_user))
  end

  def import_requested_observations(id_above:, continuation:)
    unless continuation
      inat_import.update(state: "Importing", started_at: Time.zone.now)
      return log("No observations requested") unless observations_requested?
    end

    parser = build_parser(id_above)
    more_pages = import_batch(parser)
    log_unlicensed_summary
    enqueue_continuation(parser.last_import_id) if more_pages &&
                                                   !inat_import.reload.canceled?
  end

  def build_parser(id_above)
    parser = Inat::PageParser.new(inat_import, per_page: BATCH_SIZE)
    parser.last_import_id = id_above
    parser
  end

  def import_batch(parser)
    @obs_this_job = 0
    while (more_pages = parsing?(parser))
      break if @obs_this_job >= BATCH_SIZE
    end
    more_pages
  end

  def enqueue_continuation(id_above)
    @continuation_enqueued = true
    log("Batch of #{@obs_this_job} obs complete. " \
        "Enqueueing continuation from id_above #{id_above}.")
    InatImportJob.perform_later(inat_import,
                                id_above: id_above,
                                continuation: true)
  end

  def observations_requested?
    inat_import[:import_all].present? ||
      inat_id_list.present? ||
      inat_import.inat_url.present?
  end

  def inat_id_list
    inat_import.inat_ids.delete(" ")
  end

  # Import the next page of iNat API results,
  # returning true if there are more pages of results, false if done.
  def parsing?(parser)
    parsed_page = parser.next_page
    return false if parsing_should_stop?(parsed_page)

    import_parsed_page_of_observations(parsed_page)
    parser.last_import_id = parsed_page["results"].last["id"]
    more_pages?(parsed_page)
  end

  def parsing_should_stop?(parsed_page)
    parsed_page.nil? ||
      parsed_page["total_results"].zero? ||
      inat_import.reload.canceled?
  end

  def import_parsed_page_of_observations(parsed_page)
    log_new_page(parsed_page)
    unless @importables_set
      updates = { importables: parsed_page["total_results"] }
      unless inat_import.total_importables.to_i.positive?
        updates[:total_importables] = parsed_page["total_results"]
      end
      inat_import.update(updates)
      @importables_set = true
    end
    observation_importer.import_page(parsed_page)
    @obs_this_job += parsed_page["results"].size
    log("Finished importing observations on parsed page")
  end

  def log_new_page(parsed_page)
    log("Got parsed page with iNat " \
      "#{parsed_page["results"].first["id"]}-" \
      "#{parsed_page["results"].last["id"]}")
    log("Results on this page: #{parsed_page["results"].size}")
    log("Total results: #{parsed_page["total_results"]}")
  end

  def more_pages?(parsed_page)
    parsed_page["total_results"] > parsed_page["page"] * parsed_page["per_page"]
  end

  def observation_importer
    @observation_importer ||=
      ::Inat::ObservationImporter.new(inat_import, user, self)
  end

  def log_unlicensed_summary
    unlicensed_obs = observation_importer.unlicensed_obs_count
    skipped_images = observation_importer.skipped_images_count

    if inat_import.import_others
      if skipped_images.positive?
        inat_import.add_response_error(
          :inat_skipped_images_summary.t(count: skipped_images)
        )
      end
    else
      log_own_unlicensed_summary(unlicensed_obs)
    end
  end

  def log_own_unlicensed_summary(unlicensed_obs)
    return unless unlicensed_obs.positive?

    inat_import.add_response_error(
      :inat_unlicensed_obs_summary.t(count: unlicensed_obs)
    )
  end

  def non_rescuable?(error)
    error.is_a?(SignalException) ||
      error.is_a?(SystemExit) ||
      error.is_a?(NoMemoryError) ||
      error.is_a?(SystemStackError) ||
      error.is_a?(ScriptError)
  end

  def safe_done
    original_exception = $ERROR_INFO
    done
  rescue StandardError => e
    Rails.logger.error(
      "InatImportJob: done failed for import #{inat_import&.id}: #{e.message}"
    )
    # Re-raise if done failed on the happy path so the job fails visibly
    # and SolidQueue can retry. Swallow only when already handling an error,
    # so the original exception is not masked.
    raise unless original_exception
  end

  def done
    log("Updating inat_import state to Done")
    inat_import.update(state: "Done", ended_at: Time.zone.now)
    update_user_inat_username
  end

  # A convenience to let a user to create/update their iNat username
  # simply by entering it in the import form.
  def update_user_inat_username
    return unless inat_username_updateable?

    user.update(inat_username: inat_username)
    log("Updated user inat_username")
  end

  def inat_username_updateable?
    # Don't update a SuperImporter's inat_username because
    # InatImport.inat_username could be someone else's inat_username.
    return false if InatImport.super_importer?(user)

    # Prevent changing inat_username to a non-existent iNat login
    # No errors or any imports means that iNat accepted the inat_username,
    # so it's real inat_username.
    response_errors.empty? ||
      imported_count.to_i.positive?
  end
end
