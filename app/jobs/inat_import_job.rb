# frozen_string_literal: true

class InatImportJob < ApplicationJob
  include Inat::Constants

  queue_as :default

  delegate :token, to: :@inat_import

  def perform(inat_import)
    create_ivars(inat_import)
    # use_auth_code_to_obtain_oauth_access_token
    # trade_access_token_for_jwt_api_token
    authenticate
    ensure_importing_own_observations
    import_requested_observations
  rescue StandardError => e
    log("Error occurred: #{e.message}")
    @inat_import.add_response_error(e)
  ensure
    done
  end

  private

  def create_ivars(inat_import)
    @inat_import = inat_import
    log(
      "InatImportJob #{inat_import.id} started, user: #{inat_import.user_id}"
    )
    @user = @inat_import.user
  end

  def authenticate
    token_service = Inat::APIToken.new(
      app_id: APP_ID, site: SITE,
      redirect_uri: REDIRECT_URI,
      secret: Rails.application.credentials.inat.secret
    )
    token = token_service.obtain_api_token(@inat_import.token)
    @inat_import.update(token: token)
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

    @inat_logged_in_user = JSON.parse(response.body)["results"].first["login"]
    log("inat_logged_in_user: #{@inat_logged_in_user}")
    raise(:inat_wrong_user.t) unless right_user?(@inat_logged_in_user)
  end

  def super_importer?
    InatImport.super_importers.include?(@user)
  end

  def right_user?(inat_logged_in_user)
    inat_logged_in_user == @inat_import.inat_username
  end

  def import_requested_observations
    @inat_import.update(state: "Importing")
    inat_ids = inat_id_list
    return log("No observations requested") if @inat_import[:import_all].
                                               blank? && inat_ids.blank?

    # Search for one page of results at a time, until done with all pages
    # To get one page, use iNats `per_page` & `id_above` params.
    # https://api.inaturalist.org/v1/docs/#!/Observations/get_observations
    parser = Inat::PageParser.new(@inat_import, inat_ids, restricted_user_login)
    while parsing?(parser); end
  end

  def inat_id_list
    @inat_import.inat_ids.delete(" ")
  end

  def parsing?(parser)
    # get a page of observations with id > id of last imported obs
    parsed_page = parser.next_page
    return false if parsed_page.nil?

    @inat_import.update(importables: parsed_page["total_results"])
    return false if page_empty?(parsed_page)

    import_page(parsed_page)

    parser.last_import_id = parsed_page["results"].last["id"]
    return true unless last_page?(parsed_page)

    log("Imported requested observations")
    false
  end

  def page_empty?(page)
    page["total_results"].zero?
  end

  def last_page?(parsed_page)
    parsed_page["total_results"] <=
      parsed_page["page"] * parsed_page["per_page"]
  end

  # limit iNat API search to observations by iNat user with this login
  def restricted_user_login
    if super_importer?
      nil
    else
      @inat_import.inat_username
    end
  end

  def import_page(page)
    observation_importer.import_page(page)
  end

  def observation_importer
    @observation_importer ||= ::Inat::ObservationImporter.new(@inat_import, @user)
  end

  def done
    log("Updating inat_import state to Done")
    @inat_import.update(state: "Done", ended_at: Time.zone.now)
    update_user_inat_username
  end

  def update_user_inat_username
    # Prevent MO users from setting their inat_username
    # to a non-existent iNat login
    return unless job_successful_enough?

    @inat_import.user.update(inat_username: @inat_import.inat_username)
    log("Updated user inat_username")
  end

  # job successful enough to justify updating the MO user's iNat user_name
  def job_successful_enough?
    @inat_import.response_errors.empty? ||
      @inat_import.imported_count&.positive?
  end
end
