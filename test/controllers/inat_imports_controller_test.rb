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
    assert_select("textarea#inat_import_new_inat_ids", true,
                  "Form needs a textarea for inputting iNat ids")
    assert_select("input#inat_import_new_inat_username", true,
                  "Form needs a field for inputting iNat username")
    assert_select(
      "input[type=checkbox][id=inat_import_new_consent]", true,
      "Form needs checkbox requiring consent"
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
      "input[name=?][value=?]",
      "inat_import_new[inat_username]",
      user.inat_username, true,
      "InatImport should pre-fill `inat_username` " \
      "with user's inat_username"
    )
  end

  def test_create_cancel_reset
    user = users(:ollie)
    import = inat_imports(:ollie_inat_import)
    assert(import.canceled?, "Test needs a canceled InatImport fixture")
    id = "123"
    params = { inat_ids: id, inat_username: user.inat_username,
               consent: 1, confirmed: 1 }

    login(user.login)
    post(:create, params: params)

    assert_not(import.reload.canceled?,
               "`cancel` should be false when starting an import")
  end

  def test_create_missing_username
    user = users(:rolf)
    id = "123"
    params = { inat_ids: id }

    login(user.login)
    post(:create, params: params)

    assert_flash_text(:inat_missing_username.l)
    assert_form_action(action: :create)
  end

  def test_create_no_observations_designated
    params = { inat_username: "anything", inat_ids: "",
               consent: 1 }
    login
    assert_no_difference("Observation.count",
                         "Imported observation(s) though none designated") do
      post(:create, params: params)
    end

    assert_flash_text(:inat_list_xor_all.l)
  end

  def test_create_list_and_all
    params = { inat_username: "anything", inat_ids: "7,8,9",
               all: 1, consent: 1 }
    login

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
    params = { inat_username: "anything", inat_ids: "123*",
               consent: 1 }
    login
    assert_no_difference("Observation.count",
                         "Imported observation(s) though none designated") do
      post(:create, params: params)
    end

    assert_flash_text(:runtime_illegal_inat_id.l)
  end

  def test_create_no_consent
    params = { inat_username: "anything", inat_ids: 123,
               consent: 0 }
    login
    assert_no_difference("Observation.count",
                         "iNat obss imported without consent") do
      post(:create, params: params)
    end

    assert_flash_text(:inat_consent_required.l)
  end

  def test_allows_maximum_ids
    user = users(:rolf)
    inat_username = "rolf" # use different inat_username to test if it's updated
    inat_import = inat_imports(:rolf_inat_import)
    assert_equal("Unstarted", inat_import.state,
                 "Need a Unstarted inat_import fixture")
    assert_equal(0, inat_import.total_imported_count.to_i,
                 "Test needs InatImport fixture without prior imports")

    id = 1_234_567_890
    reps = InatImportsController::Validators::MAX_ID_LIST_SIZE / id.to_s.length
    id_list = (id.to_s * reps).chop

    login(user.login)

    assert_no_difference(
      "Observation.count",
      "Authorization request to iNat shouldn't create MO Observation(s)"
    ) do
      post(:create,
           params: { inat_ids: id_list, inat_username: inat_username,
                     consent: 1, confirmed: 1 })
    end

    assert_response(:redirect)
    assert_equal(id_list, inat_import.reload.inat_ids,
                 "Failed to save inat_ids at maximum length")
  end

  def test_strips_trailing_commas_and_space_chars_from_id_list
    inat_import = inat_imports(:rolf_inat_import)
    user = inat_import.user
    assert_equal("Unstarted", inat_import.state,
                 "Need a Unstarted inat_import fixture")
    id_list = "123,456,789, \n"
    expected_saved_id_list = "123,456,789"

    login(user.login)

    post(:create,
         params: { inat_ids: id_list,
                   inat_username: "", # omit this to force form reload
                   consent: 1 })

    assert_form_action(action: :create)
    assert_select(
      "textarea#inat_import_new_inat_ids",
      { text: expected_saved_id_list, count: 1 },
      "inat_ids textarea should have trailing commas and whitespace stripped"
    )
  end

  def test_create_too_many_ids_listed
    # generate an id list that's barely too long
    id_list = ""
    id = 1_234_567_890
    until id_list.length > InatImportsController::Validators::MAX_ID_LIST_SIZE
      id_list += "#{id += 1},"
    end

    params = { inat_username: "anything", inat_ids: id_list, consent: 1 }

    login
    post(:create, params: params)

    assert_form_action(action: :create)
    assert_flash_text(:inat_too_many_ids_listed.l)
  end

  def test_create_previously_imported
    user = users(:rolf)
    inat_id = "1123456"
    Observation.create(
      where: "North Falmouth, Massachusetts, USA",
      user: user,
      when: "2024-09-08",
      source: Observation.sources[:mo_inat_import],
      inat_id: inat_id
    )

    params = { inat_username: "anything", inat_ids: inat_id,
               consent: 1, confirmed: 1 }
    login
    assert_no_difference("Observation.count",
                         "Imported a previously imported iNat obs") do
      post(:create, params: params)
    end

    assert_flash_text(/#{:inat_previous_import.l(count: 1)}/)
    # It should continue even if some ids were previously imported
    # The job will exclude previous imports via the iNat API
    # `without_field: "Mushroom Observer URL"` param.
    assert_redirected_to(INAT_AUTHORIZATION_URL)
  end

  def test_create_strip_inat_username
    user = users(:mary)
    assert(APIKey.where(user: user, notes: MO_API_KEY_NOTES).none?,
           "Test needs user fixture without an MO API key for iNat imports")
    inat_username = " #{user.name} " # simulate typing extra spaces
    inat_import = inat_imports(:mary_inat_import)
    assert_equal("Unstarted", inat_import.state,
                 "Need a Unstarted inat_import fixture")

    login(user.login)

    assert_no_difference(
      "Observation.count",
      "Authorization request to iNat shouldn't create MO Observation(s)"
    ) do
      post(:create,
           params: { inat_ids: 123_456_789, inat_username: inat_username,
                     consent: 1, confirmed: 1 })
    end

    assert(
      APIKey.where(user: user, notes: MO_API_KEY_NOTES).
             where.not(verified: nil).one?,
      "MO should assure user has personal verified API key for iNat imports"
    )
    assert_response(:redirect)
    assert_equal(
      user.name, inat_import.reload.inat_username,
      "It should strip leading/trailing whitespace from inat_username"
    )
  end

  def test_create_authorization_request
    user = users(:rolf)
    inat_username = "rolf" # use different inat_username to test if it's updated
    inat_import = inat_imports(:rolf_inat_import)
    assert_equal("Unstarted", inat_import.state,
                 "Need a Unstarted inat_import fixture")
    assert_equal(0, inat_import.total_imported_count.to_i,
                 "Test needs InatImport fixture without prior imports")
    inat_ids = "123,456,789"

    login(user.login)

    assert_no_difference(
      "Observation.count",
      "Authorization request to iNat shouldn't create MO Observation(s)"
    ) do
      post(:create,
           params: { inat_ids: inat_ids, inat_username: inat_username,
                     consent: 1, confirmed: 1 })
    end

    assert_redirected_to(INAT_AUTHORIZATION_URL)
    assert_equal(inat_ids.split(",").length, inat_import.reload.importables,
                 "Failed to save InatImport.importables")
    assert_equal("Authorizing", inat_import.reload.state,
                 "MO should be awaiting authorization from iNat")
    assert_equal(
      InatImport.sum(:total_seconds) / InatImport.sum(:total_imported_count),
      inat_import.avg_import_time
    )
    assert_equal(inat_username, inat_import.inat_username,
                 "Failed to save InatImport.inat_username")
  end

  def test_create_shows_confirmation_with_estimate
    user = users(:rolf)
    inat_username = "rolf"
    inat_ids = "123,456"
    estimate_response = { total_results: 2 }.to_json

    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: estimate_response)
    login(user.login)

    post(:create,
         params: { inat_ids: inat_ids, inat_username: inat_username,
                   consent: 1 })

    assert_response(:success)
    assert_template(:confirm)
    body = @response.body
    assert_match(:inat_import_confirm_estimate_caption.l, body)
    assert_select("#estimated_count", "2")
    assert_match(:inat_import_confirm_time_estimate_caption.l, body)
    assert_select("#estimated_time", "00:00:24")
  end

  def test_create_confirmed_with_superform_params
    user = users(:rolf)
    inat_import = inat_imports(:rolf_inat_import)
    inat_username = "rolf"
    inat_ids = "123,456"

    login(user.login)

    post(:create,
         params: {
           confirmed: 1,
           inat_import_confirm: {
             inat_username: inat_username,
             inat_ids: inat_ids,
             import_all: "",
             consent: "1"
           }
         })

    assert_redirected_to(INAT_AUTHORIZATION_URL)
    assert_equal(inat_username, inat_import.reload.inat_username,
                 "Should flatten inat_username from namespaced params")
  end

  def test_create_go_back_with_superform_params
    login(users(:rolf).login)

    post(:create,
         params: {
           go_back: 1,
           inat_import_confirm: {
             inat_username: "rolf",
             inat_ids: "123",
             import_all: "",
             consent: "1"
           }
         })

    assert_response(:success)
    assert_select("form#inat_import_new_form")
    assert_select(
      "textarea#inat_import_new_inat_ids",
      { text: "123", count: 1 },
      "Form should preserve inat_ids from namespaced params"
    )
  end

  def test_create_confirmation_go_back
    user = users(:rolf)
    inat_username = "rolf"
    inat_ids = "123,456"

    login(user.login)

    post(:create,
         params: { inat_ids: inat_ids,
                   inat_username: inat_username,
                   consent: 1, go_back: 1 })

    assert_response(:success)
    assert_select("form#inat_import_new_form")
    assert_select(
      "textarea#inat_import_new_inat_ids",
      { text: inat_ids, count: 1 },
      "Form should preserve inat_ids when going back"
    )
  end

  def test_create_confirmation_estimate_unavailable
    user = users(:rolf)
    inat_username = "rolf"
    inat_ids = "123"

    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 500, body: "error")
    login(user.login)

    post(:create,
         params: { inat_ids: inat_ids, inat_username: inat_username,
                   consent: 1 })

    assert_flash_error
    assert_response(:success)
    assert_select("form#inat_import_new_form")
  end

  def test_authorization_response_denied
    login

    get(:authorization_response, params: authorization_denial_callback_params)

    assert_redirected_to(observations_path)
    assert_flash_error
  end

  def test_import_all
    user = users(:mary)
    params = { inat_username: user.inat_username, all: 1,
               consent: 1, confirmed: 1 }

    login(user.login)
    post(:create, params: params)

    assert_redirected_to(INAT_AUTHORIZATION_URL, allow_other_host: true)
  end

  def test_allow_first_time_import_all
    user = users(:rolf)
    assert_nil(user.inat_username, "Test needs fixture without inat_username")
    params = { inat_username: "anything", all: 1, consent: 1, confirmed: 1 }

    login(user.login)
    post(:create, params: params)

    assert_redirected_to(INAT_AUTHORIZATION_URL, allow_other_host: true)
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

  def test_super_importer_can_import_specific_ids_from_another_user
    user = users(:dick) # Dick is a super_importer
    assert(InatImport.super_importer?(user),
           "Test requires user to be a super_importer")
    params = { inat_username: "other_inat_user", inat_ids: "12345",
               consent: 1, confirmed: 1 }

    login(user.login)
    post(:create, params: params)

    assert_redirected_to(INAT_AUTHORIZATION_URL)
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
