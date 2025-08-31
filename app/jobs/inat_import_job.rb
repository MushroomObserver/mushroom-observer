# frozen_string_literal: true

class InatImportJob < ApplicationJob
  attr_accessor :inat_import

  include Inat::Constants

  queue_as :default

  delegate :canceled?, to: :inat_import
  delegate :imported_count, to: :inat_import
  delegate :inat_username, to: :inat_import
  delegate :response_errors, to: :inat_import
  delegate :token, to: :inat_import
  delegate :user, to: :inat_import

  def perform(inat_import)
    create_ivars(inat_import)
    authenticate
    ensure_importing_own_observations
    import_requested_observations
  rescue StandardError => e
    log("Error occurred: #{e.message}")
    inat_import.add_response_error(e)
  ensure
    done
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
      secret: Rails.application.credentials.inat.secret
    )
    token = token_service.obtain_api_token(inat_import.token)
    inat_import.update(token: token)
    log("Obtained iNat API token")
  end

  # Prevent MO users from importing other users' iNat observations,
  # unless they are super importers.
  def ensure_importing_own_observations
    return log("Skipped own-obs check (SuperImporter)") if super_importer?

    begin
      response = Inat::APIRequest.new(token).request(path: "users/me")
    rescue RestClient::Unauthorized, RestClient::ExceptionWithResponse => e
      raise("iNat API user request failed: #{e.message}")
    end

    inat_logged_in_user = JSON.parse(response.body)["results"].first["login"]
    log("inat_logged_in_user: #{inat_logged_in_user}")
    raise(:inat_wrong_user.t) unless right_user?(inat_logged_in_user)
  end

  def super_importer?
    InatImport.super_importers.include?(user)
  end

  def right_user?(inat_logged_in_user)
    inat_logged_in_user == inat_username
  end

  def import_requested_observations
    inat_import.update(state: "Importing")
    inat_ids = inat_id_list
    return log("No observations requested") if inat_import[:import_all].
                                               blank? && inat_ids.blank?

    # Request a page of iNat observations at a time, until done with all pages
    # (or canceled).
    parser = Inat::PageParser.new(inat_import)
    while parsing?(parser); end
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
    log("Got iNat response page #{parsed_page["page"]}")
    inat_import.update(importables: parsed_page["total_results"])
    observation_importer.import_page(parsed_page)
    log("Imported observations on page ##{parsed_page["page"]}")
  end

  def more_pages?(parsed_page)
    parsed_page["total_results"] > parsed_page["page"] * parsed_page["per_page"]
  end

  def observation_importer
    @observation_importer ||=
      ::Inat::ObservationImporter.new(inat_import, user)
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
    return false if InatImport.super_importers.include?(user)

    # Prevent changing inat_username to a non-existent iNat login
    # No errors or any imports means that iNat accepted the inat_username,
    # so it's real inat_username.
    response_errors.empty? ||
      imported_count.to_i.positive?
  end
end
