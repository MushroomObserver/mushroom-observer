# frozen_string_literal: true

require("test_helper")

# a duck type of API2::ImageAPI with enough attributes
# to preventInatImportsController from throwing an error
class MockImageAPI
  attr_reader :errors, :results

  def initialize(errors: [], results: [])
    @errors = errors
    @results = results
  end
end

# test importing iNaturalist Observations to Mushroom Observer
class InatImportsControllerTest < FunctionalTestCase
  include ActiveJob::TestHelper
  include Inat::Constants

  # stub the iNat API request for the expected import count
  def stub_count_request(inat_username:, ids: nil, body: "{}")
    stub_request(
      :get,
      "#{API_BASE}/observations" \
      "?iconic_taxa=#{ICONIC_TAXA}" \
      "&id=#{ids}" \
      "&only_id=true&page=1&per_page=1" \
      "&user_id=#{inat_username}" \
      "&without_field=Mushroom%20Observer%20URL"
    ).with(
      body: body,
      headers: {
        "Accept" => "application/json",
        "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
        "Authorization" => "Bearer",
        "Content-Length" => "2",
        "Content-Type" => "application/json",
        "Host" => "api.inaturalist.org",
        "User-Agent" => "rest-client/2.1.0 (darwin24 x86_64) ruby/3.3.6p108"
      }
    ).to_return(status: 200, body: body, headers: {})
  end

  def test_show
    import = inat_imports(:rolf_inat_import)
    tracker = InatImportJobTracker.create(inat_import: import.id)

    login

    get(:show, params: { id: import.id, tracker_id: tracker.id })

    assert_response(:success)
  end

  def test_new_inat_import
    login(users(:rolf).login)
    get(:new)

    assert_response(:success)
    assert_form_action(action: :create)
    assert_select("input#inat_ids", true,
                  "Form needs a field for inputting iNat ids")
    assert_select("input#inat_username", true,
                  "Form needs a field for inputting iNat username")
    assert_select("input[type=checkbox][id=consent]", true,
                  "Form needs checkbox requiring consent")
    assert(
      assert_select("#preview").text.include?(
        "#{:inat_import_expected_count.l}: #{:inat_import_tbd.l}"
      ),
      "Form missing expected import count"
    )
    assert(
      assert_select("#preview").text.include?(
        "#{:inat_expected_imports_link.l}: #{:inat_import_tbd.l}"
      ),
      "Form missing expected imports link"
    )
  end

  def test_new_inat_import_already_importing
    user = users(:katrina)
    import = inat_imports(:katrina_inat_import)
    tracker = inat_import_job_trackers(:katrina_tracker)

    login(user.login)
    get(:new)

    assert_flash_warning(
      "Should flash warning if user starts iNat import while another is running"
    )
    assert_redirected_to(
      inat_import_path(import, params: { tracker_id: tracker.id })
    )
  end

  def test_new_inat_import_inat_username_prefilled
    user = users(:mary)
    assert(user.inat_username.present?,
           "Test needs a user fixture with an inat_username")

    login(mary.login)
    get(:new)

    assert_select(
      "input[name=?][value=?]", "inat_username", user.inat_username, true,
      "InatImport should pre-fill `inat_username` with user's inat_username"
    )
  end

  def test_create_counts_and_links
    inat_import = inat_imports(:mary_inat_import)
    user = inat_import.user
    inat_ids = "123,456,789"

    params = { inat_username: user.inat_username,
               inat_ids: inat_ids,
               all: "0",
               consent: "1",
               inat_import_expected_count: :inat_import_tbd.l,
               inat_expected_imports_link: :inat_import_tbd.l }

    login(user.login)
    stub_count_request(inat_username: inat_import.inat_username,
                       ids: inat_ids)
    disable_unsafe_html_filter
    post(:create, params: params)

    assert_form_action({ action: :create },
                       "InatImport form should reload after user fills it out")
    # It should display expected import count
    # If should display link to expected imports
  end

  def test_create_cancel_reset
    import = inat_imports(:ollie_inat_import)
    user = import.user
    assert(import.canceled?, "Test needs a canceled InatImport fixture")
    params = {
      inat_ids: import.inat_ids,
      inat_username: user.inat_username,
      consent: 1
    }

    login(user.login)
    disable_unsafe_html_filter
    stub_count_request(inat_username: user.inat_username)
    post(:create, params: params)

    assert_not(import.reload.canceled?,
               "`cancel` should be false when starting an import")
  end

  def test_create_missing_inat_username
    import = inat_imports(:mary_inat_import)
    import.update(inat_username: nil)
    params = {
      inat_username: import.inat_username,
      inat_ids: import.inat_ids, all: 0, consent: 1
    }

    login(import.user.login)
    disable_unsafe_html_filter
    stub_count_request(inat_username: import.inat_username,
                       ids: import.inat_ids)
    post(:create, params: params)

    assert_flash_text(:inat_missing_username.l)
    assert_form_action(action: :create)
  end

  def test_create_no_observations_designated
    import = inat_imports(:mary_inat_import)
    params = {
      inat_username: import.inat_username,
      inat_ids: "",
      all: 0,
      consent: 1
    }

    login(import.user.login)
    disable_unsafe_html_filter
    stub_count_request(inat_username: import.inat_username,
                       ids: import.inat_ids)

    assert_no_difference("Observation.count",
                         "Imported observation(s) though none designated") do
      post(:create, params: params)
    end

    assert_flash_text(:inat_list_xor_all.l)
  end

  def test_create_list_and_all
    import = inat_imports(:mary_inat_import)
    params = {
      inat_username: import.inat_username,
      inat_ids: import.inat_ids, all: 1,
      consent: 1
    }

    login(import.user.login)
    stub_count_request(inat_username: import.inat_username,
                       ids: import.inat_ids)
    disable_unsafe_html_filter

    assert_no_difference(
      "Observation.count",
      "Imported obs though user both listed IDs and checked Import All"
    ) do
      post(:create, params: params)
    end
    assert_flash_text(
      :inat_list_xor_all.l,
      "It should warn about listing IDs while checking Import All"
    )
  end

  def test_create_illegal_observation_id
    import = inat_imports(:mary_inat_import)
    import.update(inat_ids: "123*")
    params = {
      inat_username: import.inat_username,
      inat_ids: import.inat_ids, all: 0,
      consent: 1
    }

    login(import.user.login)
    stub_count_request(inat_username: import.inat_username,
                       ids: import.inat_ids)
    disable_unsafe_html_filter

    assert_no_difference("Observation.count",
                         "Imported observation(s) though none designated") do
      post(:create, params: params)
    end

    assert_flash_text(:runtime_illegal_inat_id.l)
  end

  def test_create_no_consent
    import = inat_imports(:mary_inat_import)
    params = {
      inat_username: import.inat_username,
      inat_ids: import.inat_ids, all: 0,
      consent: 0
    }

    login(import.user.login)
    stub_count_request(inat_username: import.inat_username,
                       ids: import.inat_ids)
    disable_unsafe_html_filter

    assert_no_difference("Observation.count",
                         "iNat obss imported without consent") do
      post(:create, params: params)
    end

    assert_flash_text(:inat_consent_required.l)
  end

  def test_create_too_many_ids_listed
    # generate an id list that's too long for the inat_ids column
    # It'ss a string column with max length 255
    id_list = ""
    id = 1_234_567_890
    id_list += "#{id += 1}," until id_list.length > 255

    import = inat_imports(:mary_inat_import)
    # save as much as possible
    import.update(inat_ids: id_list[0, 255])
    params = {
      inat_username: import.inat_username,
      inat_ids: id_list, all: 0,
      consent: 1
    }

    login(import.user.login)
    stub_count_request(inat_username: import.inat_username,
                       ids: import.inat_ids)
    disable_unsafe_html_filter
    post(:create, params: params)

    assert_form_action(action: :create)
    assert_flash_text(:inat_too_many_ids_listed.l)
  end

  def test_create_previously_imported
    inat_id = "1123456"
    Observation.create(
      where: "North Falmouth, Massachusetts, USA",
      user: mary,
      when: "2024-09-08",
      source: Observation.sources[:mo_inat_import],
      inat_id: inat_id
    )
    import = inat_imports(:mary_inat_import)
    import.update(inat_ids: inat_id)
    params = {
      inat_username: import.inat_username,
      inat_ids: import.inat_ids, all: 0,
      consent: 1
    }

    login(import.user.login)
    stub_count_request(inat_username: import.inat_username,
                       ids: import.inat_ids)
    disable_unsafe_html_filter

    assert_no_difference("Observation.count",
                         "Imported a previously imported iNat obs") do
      post(:create, params: params)
    end
    assert_flash_text(/iNat #{inat_id} previously imported/)
  end

  def test_create_previously_mirrored
    user = users(:rolf)
    inat_id = "1234567"
    mirrored_obs = Observation.create(
      where: "North Falmouth, Massachusetts, USA",
      user: user,
      when: "2023-09-08",
      inat_id: nil,
      # When Pulk's `mirror`Python script copies an MO Obs to iNat,
      # it adds a text in this form to the MO Obs notes
      # See https://github.com/JacobPulk/mirror
      notes: { Other: "Mirrored on iNaturalist as <a href=\"https://www.inaturalist.org/observations/#{inat_id}\">observation #{inat_id}</a> on December 18, 2023" }
    )
    params = { inat_username: "anything", inat_ids: inat_id, consent: 1 }

    login
    disable_unsafe_html_filter
    assert_no_difference(
      "Observation.count",
      "Imported an iNat obs which had been 'mirrored' from MO"
    ) do
      post(:create, params: params)
    end

    # NOTE: 2024-09-04 jdc
    # I'd prefer that the flash include links to both obss,
    # and that this (or another) assertion check for that.
    # At the moment, it's taking too long to figure out how.
    assert_flash_text(
      "iNat #{inat_id} is a &#8220;mirror&#8221; of " \
      "existing MO Observation #{mirrored_obs.id}"
    )
  end

  def test_create_strip_inat_username
    user = users(:mary)
    assert(APIKey.where(user: user, notes: MO_API_KEY_NOTES).none?,
           "Test needs user fixture without an MO API key for iNat imports")
    inat_username = " #{user.inat_username} " # simulate typing extra spaces
    inat_import = inat_imports(:mary_inat_import)
    assert_equal("Unstarted", inat_import.state,
                 "Need a Unstarted inat_import fixture")

    stub_request(:any, authorization_url)
    login(user.login)

    assert_no_difference(
      "Observation.count",
      "Authorization request to iNat shouldn't create MO Observation(s)"
    ) do
      post(:create,
           params: { inat_ids: 123_456_789, inat_username: inat_username,
                     consent: 1 })
    end

    assert_equal(
      user.inat_username, inat_import.reload.inat_username,
      "It should strip leading/trailing whitespace from inat_username"
    )
    assert(
      APIKey.where(user: user, notes: MO_API_KEY_NOTES).
             where.not(verified: nil).one?,
      "MO should assure user has personal verified API key for iNat imports"
    )
    assert_equal(
      INAT_AUTHORIZATION_URL, @response.location,
      "It should redirect to iNat authorization if params valid and unchanged"
    )
  end

  def test_create_authorization_request
    user = users(:rolf)
    inat_import = inat_imports(:rolf_inat_import)
    inat_import.update(importables: nil) # set to nil to test if later updated
    assert_equal("Unstarted", inat_import.state,
                 "Need a Unstarted inat_import fixture")
    assert_equal(0, inat_import.total_imported_count.to_i,
                 "Need InatImport fixture without prior imports")

    stub_request(:any, authorization_url)
    login(user.login)
    post(:create, params: { inat_ids: inat_import.inat_ids,
                            inat_username: inat_import.inat_username,
                            consent: 1 })

    assert_equal(
      INAT_AUTHORIZATION_URL, @response.location,
      "It should redirect to iNat authorization if params valid and unchanged"
    )
    assert_equal("Authorizing", inat_import.reload.state,
                 "MO should be awaiting authorization from iNat")
    assert_equal(
      inat_import.inat_ids.split(",").length, inat_import.reload.importables,
      "Failed to save InatImport.importables"
    )
    assert_equal(
      InatImport.sum(:total_seconds) / InatImport.sum(:total_imported_count),
      inat_import.avg_import_time
    )
  end

  def test_authorization_response_denied
    login

    get(:authorization_response, params: authorization_denial_callback_params)

    assert_redirected_to(observations_path)
    assert_flash_error
  end

  def test_import_all_anothers_observations
    user = users(:dick) # Dick is a iNat superimporter
    params = { inat_username: "anything", inat_ids: nil,
               consent: 1, all: 1 }

    login(user.login)
    assert_no_difference("Observation.count",
                         "iNat obss imported without consent") do
      post(:create, params: params)
    end

    assert_flash_text(:inat_importing_all_anothers.t)
    assert_form_action(action: :create)
  end

  def test_import_authorized
    user = users(:rolf)
    assert_blank(user.inat_username,
                 "Test needs user fixture without an iNat username")
    inat_import = inat_imports(:rolf_inat_import)

    # empty id_list to prevent importing any observations in this test
    inat_import.inat_ids = ""
    inat_import.save
    inat_authorization_callback_params = { code: "MockCode" }

    login(user.login)

    assert_difference(
      "enqueued_jobs.size", 1, "Failed to enqueue background job"
    ) do
      assert_enqueued_with(job: InatImportJob) do
        get(:authorization_response,
            params: inat_authorization_callback_params)
      end
    end

    assert_in_delta(
      0.25, inat_import.reload.last_obs_elapsed_time, 0.25,
      "When job starts, elapsed time for 1st import should be <= 0.5 seconds"
    )

    tracker = InatImportJobTracker.where(inat_import: inat_import.id).last
    assert_redirected_to(
      inat_import_path(inat_import, params: { tracker_id: tracker.id })
    )
  end

  def test_import_all
    inat_import = inat_imports(:roy_inat_import)
    params = { inat_username: inat_import.inat_username, inat_ids: "", all: 1,
               consent: 1 }

    login(inat_import.user.login)
    post(:create, params: params)

    assert_redirected_to(INAT_AUTHORIZATION_URL, allow_other_host: true)
  end

  def test_inat_username_unchanged_if_authorization_denied
    user = users(:rolf)
    assert_blank(user.inat_username,
                 "Test needs user fixture without an iNat username")
    inat_username = "inat_username"
    inat_import = inat_imports(:rolf_inat_import)
    inat_import.update(
      inat_ids: "", # Blank id_list ito prevent importing any observations
      inat_username: inat_username
    )

    login(user.login)
    get(:authorization_response,
        params: authorization_denial_callback_params)

    assert_blank(
      user.reload.inat_username,
      "User inat_username shouldn't change if user denies authorization to MO"
    )
  end

  def test_cancel
    import = inat_imports(:katrina_inat_import)
    assert(import.job_pending? && !import.canceled?,
           "Test needs a Import fixture with a uncancelled, pending Job")

    login
    get(:cancel, params: { id: import.id })

    assert_response(:success)
    assert_template(:show)
    assert(import.reload.canceled?,
           "Clicking cancel button should make InatImport.canceled? == true")
  end

  ########## Utilities

  # iNat url where user is sent in order to authorize MO access
  # to iNat confidential data
  # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
  def authorization_url
    "https://www.inaturalist.org/oauthenticate/authorize?" \
    "client_id=#{Rails.application.credentials.inat.id}" \
    "&redirect_uri=#{REDIRECT_URI}" \
    "&response_type=code"
  end

  def authorization_denial_callback_params
    { error: "access_denied",
      error_description:
        "The resource owner or authorization server denied the request." }
  end
end
