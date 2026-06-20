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
    assert_select("textarea#inat_import_inat_ids", true,
                  "Form needs a textarea for inputting iNat ids")
    assert_select("input#inat_import_inat_username", true,
                  "Form needs a field for inputting iNat username")
    assert_select(
      "input[type=checkbox][id=inat_import_consent]", true,
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
      "inat_import[inat_username]",
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

  def test_reload_preserves_checkbox_state
    user = users(:rolf)
    params = { inat_ids: "123", consent: "1", all: "1" }

    login(user.login)
    post(:create, params: params)

    assert_form_action(action: :create)
    assert_select(
      "input[type=checkbox]" \
      "[id=inat_import_consent][checked]", true,
      "Consent checkbox should remain checked on reload"
    )
    assert_select(
      "input[type=checkbox]" \
      "[id=inat_import_all][checked]", true,
      "Import All checkbox should remain checked on reload"
    )
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

  def test_no_numeric_ids_in_list_rejected
    login
    post(:create,
         params: { inat_ids: "id\nobservation", inat_username: "anything",
                   consent: 1 })

    assert_flash_text(:runtime_illegal_inat_id.l,
                      "Input with no numeric IDs should be rejected")
    assert_form_action(action: :create)
    assert_select(
      "textarea#inat_import_inat_ids",
      { text: "id\nobservation", count: 1 },
      "Reloaded form should show the original input"
    )
  end

  def test_alphanumeric_token_rejected_as_malformed_id
    login
    post(:create,
         params: { inat_ids: "id\n123456a", inat_username: "anything",
                   consent: 1 })

    assert_flash_text(:runtime_illegal_inat_id.l,
                      "Alphanumeric token (e.g. 123456a) should be " \
                      "rejected as a malformed ID")
    assert_form_action(action: :create)
    assert_select(
      "textarea#inat_import_inat_ids",
      { text: "id\n123456a", count: 1 },
      "Reloaded form should show the original input"
    )
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

  def test_illegal_chars_preserved_in_reloaded_form
    login
    post(:create,
         params: { inat_ids: "123*", inat_username: "anything", consent: 1 })

    assert_flash_text(:runtime_illegal_inat_id.l,
                      "Should warn about illegal characters")
    assert_select(
      "textarea#inat_import_inat_ids",
      { text: "123*", count: 1 },
      "Reloaded form should show raw input so user can identify " \
      "the illegal character"
    )
  end

  def test_newline_delimited_ids_accepted_and_normalized
    user = users(:rolf)
    inat_import = inat_imports(:rolf_inat_import)
    assert_equal("Unstarted", inat_import.state,
                 "Need an Unstarted inat_import fixture")
    inat_ids = "368966299\n368983890\n368951839"
    expected_ids = "368966299,368983890,368951839"

    login(user.login)

    post(:create,
         params: { inat_ids: inat_ids, inat_username: "rolf",
                   consent: 1, confirmed: 1 })

    assert_redirected_to(INAT_AUTHORIZATION_URL,
                         "Newline-delimited IDs should pass validation")
    assert_equal(expected_ids, inat_import.reload.inat_ids,
                 "Newline-delimited IDs should be normalized to " \
                 "comma-separated")
    assert_equal(3, inat_import.reload.importables,
                 "importables_count should reflect the number of IDs")
  end

  def test_header_row_ignored_in_id_list
    user = users(:rolf)
    inat_import = inat_imports(:rolf_inat_import)
    assert_equal("Unstarted", inat_import.state,
                 "Need an Unstarted inat_import fixture")
    inat_ids = "id\n368966299\n368983890\n368951839"
    expected_ids = "368966299,368983890,368951839"

    login(user.login)

    post(:create,
         params: { inat_ids: inat_ids, inat_username: "rolf",
                   consent: 1, confirmed: 1 })

    assert_redirected_to(INAT_AUTHORIZATION_URL,
                         "Input with a header row should pass validation")
    assert_equal(expected_ids, inat_import.reload.inat_ids,
                 "Non-digit header token should be stripped from " \
                 "stored inat_ids")
    assert_equal(3, inat_import.reload.importables,
                 "importables_count should not include the header row token")
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

  def test_confirm_warns_about_previously_imported
    user = users(:rolf)
    inat_id = "1123456"
    Observation.create(
      where: "North Falmouth, Massachusetts, USA",
      user: user,
      when: "2024-09-08",
      external_source: Source.inaturalist,
      external_id: inat_id
    )
    estimate_response = { total_results: 1 }.to_json

    stub_request(
      :get, %r{api\.inaturalist\.org/v1/observations}
    ).to_return(status: 200, body: estimate_response)
    login(user.login)

    post(:create,
         params: { inat_ids: inat_id,
                   inat_username: "anything",
                   consent: 1 })

    assert_response(:success)
    assert_flash_text(
      /#{Regexp.escape(:inat_previous_import.l(count: 1))}/,
      "Confirmation page should warn about " \
      "previously imported IDs"
    )
  end

  def test_create_previously_imported
    user = users(:rolf)
    inat_id = "1123456"
    Observation.create(
      where: "North Falmouth, Massachusetts, USA",
      user: user,
      when: "2024-09-08",
      external_source: Source.inaturalist,
      external_id: inat_id
    )

    params = { inat_username: "anything", inat_ids: inat_id,
               consent: 1, confirmed: 1 }
    login
    assert_no_difference("Observation.count",
                         "Imported a previously imported iNat obs") do
      post(:create, params: params)
    end

    assert_flash_text(/#{Regexp.escape(:inat_previous_import.l(count: 1))}/)
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
    assert_select("#estimated_count")
    body = @response.body
    assert_match(:inat_import_confirm_estimate_caption.l, body)
    assert_select("#estimated_count", "2")
    assert_match(:inat_import_confirm_time_estimate_caption.l, body)
    assert_select("#estimated_time", "00:00:24")
  end

  def test_superimporter_import_listed_observations_estimate_excludes_user_login
    user = users(:dick) # Dick is a super_importer
    assert(InatImport.super_importer?(user),
           "Test requires user to be a super_importer")
    # Any id will work if it hasn't already been imported
    inat_ids = "339315928"
    assert_nil(Observation.find_by(inat_id: inat_ids.to_i))

    # Make the request for estimated # of imports return one result
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 1 }.to_json)

    # This stub intentionally returns 0 results when user_login is present,
    # acting as a sentinel to detect an undesired user_login filter.
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      with(query: hash_including("user_login" => user.inat_username)).
      to_return(status: 200, body: { total_results: 0 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_ids: inat_ids, inat_username: user.inat_username,
                   consent: 1, import_others: "1" })

    assert_response(:success)
    assert_select("#estimated_count")
    assert_select(
      "#estimated_count", "1",
      "Estimate should not filter by user_login if a super_importer " \
      "imports listed observations"
    )
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

  def test_skip_writeback_checkbox_admin_only
    login(users(:rolf).login)
    get(:new)
    assert_select(
      "input[type=checkbox][id=inat_import_skip_inat_writeback]", false,
      "Non-admin should not see the skip-writeback checkbox"
    )

    make_admin
    get(:new)
    assert_select(
      "input[type=checkbox][id=inat_import_skip_inat_writeback]", true,
      "Admin should see the skip-writeback checkbox"
    )
  end

  def test_skip_writeback_checkbox_checked_by_default_in_development
    make_admin
    Rails.env.stub(:development?, true) do
      get(:new)
    end

    assert_select(
      "input[type=checkbox]" \
      "[id=inat_import_skip_inat_writeback][checked]", true,
      "In development the skip-writeback box should default to checked"
    )
  end

  def test_admin_checked_skip_writeback_persists_as_skip
    inat_import = inat_imports(:rolf_inat_import)
    make_admin

    post(:create,
         params: {
           confirmed: 1,
           skip_inat_writeback: "1",
           inat_import_confirm: {
             inat_username: "rolf", inat_ids: "123", consent: "1"
           }
         })

    assert_redirected_to(INAT_AUTHORIZATION_URL)
    assert_equal("skip", inat_import.reload.writeback,
                 "Admin's checked skip-writeback box should persist as :skip")
  end

  def test_admin_unchecked_skip_writeback_persists_as_force
    inat_import = inat_imports(:rolf_inat_import)
    make_admin

    post(:create,
         params: {
           confirmed: 1,
           inat_import_confirm: {
             inat_username: "rolf", inat_ids: "123", consent: "1"
           }
         })

    assert_redirected_to(INAT_AUTHORIZATION_URL)
    assert_equal("force", inat_import.reload.writeback,
                 "Admin's unchecked skip box should persist as :force")
  end

  def test_non_admin_leaves_writeback_default
    user = users(:rolf)
    inat_import = inat_imports(:rolf_inat_import)
    login(user.login)

    post(:create,
         params: {
           confirmed: 1,
           skip_inat_writeback: "1", # ignored: only admins may set it
           inat_import_confirm: {
             inat_username: "rolf", inat_ids: "123", consent: "1"
           }
         })

    assert_redirected_to(INAT_AUTHORIZATION_URL)
    assert_equal("default", inat_import.reload.writeback,
                 "Non-admin import should leave writeback :default so the " \
                 "importer applies its environment default")
  end

  def test_superimporter_own_import_all_estimate_filters_by_user
    user = users(:dick) # Dick is a super_importer with inat_username "dick"
    assert(InatImport.super_importer?(user),
           "Test requires user to be a super_importer")
    assert_equal("dick", user.inat_username,
                 "Test requires super_importer fixture with an inat_username")

    # If user_login is excluded from the estimate query, then iNat returns
    # all iNat fungal observations of all users (a huge number).
    # Register generic stub first (lower priority).
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 19_591_724 }.to_json)
    # Register specific stub last (higher priority) to return a small count
    # when user_login is correctly included in the estimate query.
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      with(query: hash_including("user_login" => user.inat_username)).
      to_return(status: 200, body: { total_results: 1 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_username: user.inat_username, all: 1, consent: 1 })

    assert_response(:success)
    assert_select("#estimated_count")
    assert_select(
      "#estimated_count", "1",
      "Estimate for a super_importer's own import-all should filter " \
      "by user_login, not return a global count"
    )
  end

  def test_confirm_shows_unlicensed_obs_count
    user = users(:rolf)
    inat_ids = "12345"

    # Total query (no licensed filter) returns 1 (the unlicensed obs)
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 1 }.to_json)
    # Licensed query returns 0 (unlicensed obs excluded)
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      with(query: hash_including("license" => Inat::Constants::LICENSED_FILTER[:license])).
      to_return(status: 200, body: { total_results: 0 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_ids: inat_ids, inat_username: "rolf",
                   consent: 1 })

    assert_response(:success)
    assert_select("#estimated_count")
    assert_select(
      "#estimated_count", "1",
      "Estimate should include unlicensed own observations"
    )
    assert_select(
      "#unlicensed_obs_count", "1",
      "Confirm form should report unlicensed obs count (total - licensed)"
    )
  end

  def test_confirm_shows_unlicensed_obs_count_for_import_others
    user = users(:dick) # Dick is a superimporter
    assert(InatImport.super_importer?(user),
           "Test requires user to be a super_importer")

    # Total (no license filter) returns 5: 2 unlicensed will be skipped
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 5 }.to_json)
    # Licensed query (the estimate) returns 3 — registered last, matched first
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      with(query: hash_including("license" => Inat::Constants::LICENSED_FILTER[:license])).
      to_return(status: 200, body: { total_results: 3 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_ids: "1,2,3,4,5", inat_username: "anyone",
                   consent: 1, import_others: "1" })

    assert_response(:success)
    assert_select("#estimated_count")
    assert_select(
      "#estimated_count", "3",
      "Estimate for import-others should be licensed obs count"
    )
    assert_select(
      "#unlicensed_obs_count", "2",
      "Confirm form should report unlicensed obs that will be skipped"
    )
  end

  def test_confirm_renders_gracefully_when_licensed_estimate_fails
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 3 }.to_json)
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      with(query: hash_including("license" => Inat::Constants::LICENSED_FILTER[:license])).
      to_return(status: 500, body: "error")

    login(users(:rolf).login)
    post(:create,
         params: { inat_ids: "1,2,3", inat_username: "rolf", consent: 1 })

    assert_response(:success)
    assert_select("#estimated_count")
    assert_select(
      "#unlicensed_obs_count", "",
      "Unlicensed count should be blank when licensed estimate fails"
    )
  end

  def test_confirm_renders_gracefully_when_unlicensed_others_estimate_fails
    user = users(:dick) # Dick is a superimporter
    assert(InatImport.super_importer?(user),
           "Test requires user to be a super_importer")

    # Total-others request (no license filter) returns 200 with invalid JSON,
    # triggers JSON::ParserError and the rescue in fetch_unlicensed_others_count
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: "not json")
    # Licensed estimate returns valid JSON — registered last, matched first.
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      with(query: hash_including(
        "license" => Inat::Constants::LICENSED_FILTER[:license]
      )).
      to_return(status: 200, body: { total_results: 3 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_ids: "1,2,3", inat_username: "anyone",
                   consent: 1, import_others: "1" })

    assert_response(:success)
    assert_select(
      "#estimated_count", "3",
      "Estimate should still show when only unlicensed-others request fails"
    )
    assert_select(
      "#unlicensed_obs_count", "",
      "Unlicensed count should be blank when total-others estimate fails"
    )
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
    assert_select("form#inat_import_form")
    assert_select(
      "textarea#inat_import_inat_ids",
      { text: "123", count: 1 },
      "Form should preserve inat_ids from namespaced params"
    )
    assert_select(
      "input[type=checkbox][id=inat_import_all][checked]",
      false,
      "Import All should not be checked when it was not " \
      "checked before confirmation"
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
    assert_select("form#inat_import_form")
    assert_select(
      "textarea#inat_import_inat_ids",
      { text: inat_ids, count: 1 },
      "Form should preserve inat_ids when going back"
    )
  end

  def test_go_back_from_confirm_restores_original_url
    user = users(:rolf)
    original_url = "#{INAT_SITE_OBS_URL}?project_id=291058&place_id=5"
    normalized = "place_id=5&project_id=291058"

    login(user.login)
    post(:create,
         params: {
           go_back: 1,
           inat_import_confirm: {
             inat_username: "rolf_inat_user",
             inat_ids: "",
             inat_url: normalized,
             original_inat_url: original_url,
             import_all: "",
             consent: "1"
           }
         })

    assert_response(:success)
    url_field = css_select("input#inat_import_inat_url").first
    assert_not_nil(url_field, "inat_url input field not found in response")
    assert_equal(original_url, url_field["value"],
                 "Go Back must restore the original URL, not the " \
                 "normalized query string")
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
    assert_select("form#inat_import_form")
  end

  def test_authorization_response_denied
    login

    get(:authorization_response, params: authorization_denial_callback_params)

    assert_redirected_to(observations_path)
    assert_flash_error
  end

  def test_ordinary_user_can_import_all
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

  def test_import_all_anothers_observations_not_allowed
    user = users(:dick) # Dick is a iNat superimporter
    # no import_others param means superimporter chose to import own obs,
    # so "import all" for another username is blocked.
    params = { inat_username: "anything", inat_ids: nil,
               consent: 1, all: 1 }

    login(user.login)
    post(:create, params: params)

    assert_flash_text(:inat_importing_all_anothers.l)
    assert_form_action(action: :create)
  end

  def test_superimporter_not_own_can_import_all_licensed_observations
    user = users(:dick) # Dick is a iNat superimporter
    assert(InatImport.super_importer?(user),
           "Test requires user to be a super_importer")
    # import_others: "1" → not-own path; licensed filter replaces
    # username constraint, so import-all is allowed even for any username.
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 5 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_username: "anyone", inat_ids: nil,
                   consent: 1, all: 1, import_others: "1" })

    assert_response(:success)
    assert_select("#estimated_count")
  end

  def test_superimporter_not_own_import_all_without_username_blocked
    user = users(:dick) # Dick is a iNat superimporter
    assert(InatImport.super_importer?(user),
           "Test requires user to be a super_importer")
    # No username, no IDs, import_all — would fetch every fungal obs on iNat.
    # Must be blocked even though import_others is unchecked.
    login(user.login)
    post(:create,
         params: { inat_username: nil, inat_ids: nil,
                   consent: 1, all: 1 })

    assert_flash_text(:inat_missing_username.l)
    assert_form_action(action: :create)
  end

  def test_allow_superimporter_own_import_all_if_inat_username_nil
    user = users(:dick) # Dick is a iNat superimporter
    # simulate first-time import OR user.inat_username clobbered to nil
    user.update(inat_username: nil)
    params = { inat_username: "anything", all: 1, consent: 1, confirmed: 1 }

    login(user.login)
    post(:create, params: params)

    assert_redirected_to(INAT_AUTHORIZATION_URL, allow_other_host: true)
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
    assert_select("[data-controller='inat-import-job']")
    assert(import.reload.canceled?,
           "Clicking cancel button should make InatImport.canceled? == true")
  end

  ########## URL-mode tests

  INAT_SITE_OBS_URL = "https://www.inaturalist.org/observations"
  INAT_API_OBS_URL  = "https://api.inaturalist.org/v1/observations"

  def test_new_inat_import_has_inat_url_field
    login
    get(:new)

    assert_select(
      "input[name='inat_import[inat_url]']", true,
      "Form should include an inat_url text field"
    )
  end

  def test_create_with_valid_url_shows_confirmation
    user = users(:rolf)
    inat_username = "rolf_inat_user"
    url = "#{INAT_SITE_OBS_URL}?project_id=291058"

    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 5 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_username: inat_username, consent: 1 })

    assert_response(:success, "Valid URL should proceed to confirmation")
    assert_select("#estimated_count", "5",
                  "Confirmation should show estimate from URL query")
  end

  def test_importable_taxon_id_preserved_in_normalized_url
    user = users(:rolf)
    url = "#{INAT_SITE_OBS_URL}?project_id=291058&taxon_id=47170"

    stub_request(:get, %r{api\.inaturalist\.org/v1/taxa}).
      to_return(status: 200, body: {
        total_results: 1,
        results: [{ id: 47_170, ancestor_ids: [48_460, 47_170] }]
      }.to_json)
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 5 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_username: "rolf_inat_user", consent: 1 })

    url_field = css_select("input#inat_import_confirm_inat_url").first
    assert_not_nil(url_field,
                   "inat_url hidden field should be present in confirm form")
    assert_equal("project_id=291058&taxon_id=47170", url_field["value"],
                 "taxon_id should be preserved in confirm form when importable")
  end

  def test_non_importable_taxon_id_stripped_with_warning
    user = users(:rolf)
    url = "#{INAT_SITE_OBS_URL}?project_id=291058&taxon_id=3"

    stub_request(:get, %r{api\.inaturalist\.org/v1/taxa}).
      to_return(status: 200, body: {
        total_results: 1,
        results: [{ id: 3, ancestor_ids: [3] }]
      }.to_json)
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 5 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_username: "rolf_inat_user", consent: 1 })

    assert_flash_text(
      :inat_taxon_id_not_importable.l,
      "Warning should appear when taxon_id is outside Fungi/Mycetozoa"
    )
    url_field = css_select("input#inat_import_confirm_inat_url").first
    assert_not_nil(url_field,
                   "inat_url hidden field should be present in confirm form")
    assert_equal("project_id=291058", url_field["value"],
                 "taxon_id stripped from confirm form URL when not importable")
  end

  def test_create_url_and_ids_both_present_rejected
    user = users(:rolf)
    url = "#{INAT_SITE_OBS_URL}?project_id=291058"

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_ids: "123",
                   inat_username: "rolf_inat_user", consent: 1 })

    assert_flash_text(:inat_list_xor_all.l,
                      "Supplying both URL and IDs should flash XOR error")
    assert_form_action(action: :create)
  end

  def test_create_url_and_all_both_present_rejected
    user = users(:rolf)
    url = "#{INAT_SITE_OBS_URL}?project_id=291058"

    login(user.login)
    post(:create,
         params: { inat_url: url, all: "1",
                   inat_username: "rolf_inat_user", consent: 1 })

    assert_flash_text(:inat_list_xor_all.l,
                      "URL + Import All should flash XOR error")
    assert_form_action(action: :create)
  end

  def test_create_invalid_url_rejected
    login
    post(:create,
         params: { inat_url: "https://example.com/not-inat",
                   inat_username: "someone", consent: 1 })

    assert_flash_text(:inat_invalid_url.l,
                      "Non-iNat URL should flash invalid URL error")
    assert_form_action(action: :create)
  end

  def test_create_bare_query_string_rejected
    login
    post(:create,
         params: { inat_url: "project_id=291058&user_id=12345",
                   inat_username: "someone", consent: 1 })

    assert_flash_text(:inat_invalid_url.l,
                      "Bare query string should be rejected — " \
                      "user must supply a full iNat observations URL")
    assert_form_action(action: :create)
  end

  def test_create_url_with_no_surviving_params_rejected
    login
    # taxon_id=3 (Animalia) is non-importable — URLNormalizer strips it,
    # leaving an empty query string that fails validation.
    url = "#{INAT_API_OBS_URL}?taxon_id=3"
    stub_request(:get, %r{api\.inaturalist\.org/v1/taxa}).
      to_return(status: 200, body: {
        total_results: 1,
        results: [{ id: 3, ancestor_ids: [3] }]
      }.to_json)
    post(:create,
         params: { inat_url: url, inat_username: "someone", consent: 1 })

    assert_flash_text(/#{Regexp.escape(:inat_url_no_valid_filter_params.l)}/,
                      "URL without valid filter params should flash a warning")
    assert_form_action(action: :create)
  end

  def test_non_importable_sole_taxon_id_flashes_taxon_warning
    # When taxon_id is the only param and is non-importable,
    # valid_inat_url_param? fails before normalize_inat_url_param! runs.
    # The taxon-specific warning
    # must still fire so the user knows why the URL was rejected.
    login
    url = "#{INAT_API_OBS_URL}?taxon_id=3"
    stub_request(:get, %r{api\.inaturalist\.org/v1/taxa}).
      to_return(status: 200, body: {
        total_results: 1,
        results: [{ id: 3, ancestor_ids: [3] }]
      }.to_json)

    post(:create,
         params: { inat_url: url, inat_username: "someone", consent: 1 })

    # Use Regexp (assert_match) to find the taxon warning within the
    # combined multi-warning flash (assert_flash_text clears after each call).
    assert_flash_text(
      /#{Regexp.escape(:inat_taxon_id_not_importable.l)}/,
      "Taxon warning must fire even when taxon_id is the sole param " \
      "and validation fails before normalize_inat_url_param! runs"
    )
  end

  def test_non_importable_sole_taxon_id_restores_url_on_reload
    # When validation fails (URL empty after stripping non-importable taxon_id),
    # the form must reload with the original URL. original_inat_url is only set
    # in normalize_inat_url_param!, which is skipped on validation failure, so
    # reload_form must fall back to params[:inat_url].
    login
    url = "#{INAT_API_OBS_URL}?taxon_id=3"
    stub_request(:get, %r{api\.inaturalist\.org/v1/taxa}).
      to_return(status: 200, body: {
        total_results: 1,
        results: [{ id: 3, ancestor_ids: [3] }]
      }.to_json)

    post(:create,
         params: { inat_url: url, inat_username: "someone", consent: 1 })

    url_field = css_select("input#inat_import_inat_url").first
    assert_not_nil(url_field,
                   "inat_url field must be present in reloaded form")
    assert_equal(url, url_field["value"],
                 "Form must be pre-populated with the original URL after " \
                 "validation failure, not blank or normalized")
  end

  def test_stripped_sole_param_warns_which_param_was_ignored
    # When a context-stripped param (user_login) is the only param in the
    # URL, validation fails because the normalized URL is empty. The
    # ignored-params warning must fire in valid_inat_url_param? so the user
    # knows WHY the URL was rejected (not just that no valid params remain).
    login
    url = "#{INAT_API_OBS_URL}?user_login=someone_else"

    post(:create,
         params: { inat_url: url, inat_username: "rolf_inat_user",
                   consent: 1 })

    # Use Regexp: the flash also contains the no-valid-params rejection
    # message; assert_flash_text clears after the call so only one check
    # is possible. The rejection message itself is covered by
    # test_create_url_with_no_surviving_params_rejected.
    assert_flash_text(
      /#{Regexp.escape(:inat_url_params_ignored.t(params: "user_login"))}/,
      "Ignored-params warning must name user_login when it is stripped " \
      "as the sole URL param and validation fails before " \
      "normalize_inat_url_param! runs"
    )
  end

  def test_confirm_page_shows_ignored_url_params_warning
    # When a URL has ignored params alongside surviving ones, the user
    # reaches the Confirm page and must see the ignored-params warning
    # rendered by the layout's FlashNotices component.
    user = users(:rolf)
    url = "#{INAT_API_OBS_URL}?project_id=291058&user_login=someone_else"

    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 3 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_username: "rolf_inat_user",
                   consent: 1 })

    assert_flash_text(
      :inat_url_params_ignored.t(params: "user_login"),
      "Confirm page must show the ignored-params warning for user_login " \
      "stripped from the URL for a non-superimporter"
    )
    assert_select("#estimated_count", "3",
                  "Confirm page should render with the estimate")
  end

  def test_create_warns_about_ignored_url_params
    user = users(:rolf)
    # page=2 in an API URL is MO-controlled and stripped; using an API URL
    # so page is not treated as silent UI noise.
    url = "#{INAT_API_OBS_URL}?project_id=291058&page=2"

    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 5 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_username: "rolf_inat_user",
                   consent: 1 })

    assert_flash_text(
      :inat_url_params_ignored.t(params: "page"),
      "URL with stripped params should warn the user which were ignored"
    )
  end

  def test_create_confirmed_with_url_saves_inat_url
    user = users(:rolf)
    inat_import = inat_imports(:rolf_inat_import)
    url = "#{INAT_SITE_OBS_URL}?project_id=291058"
    normalized = "project_id=291058"

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_username: "rolf_inat_user",
                   consent: 1, confirmed: 1 })

    assert_redirected_to(INAT_AUTHORIZATION_URL,
                         "Confirmed URL import should redirect to iNat auth")
    assert_equal(normalized, inat_import.reload.inat_url,
                 "Normalized URL query string should be saved on InatImport")
  end

  def test_url_mode_importables_is_nil
    user = users(:rolf)
    inat_import = inat_imports(:rolf_inat_import)
    url = "#{INAT_SITE_OBS_URL}?project_id=291058"

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_username: "rolf_inat_user",
                   consent: 1, confirmed: 1 })

    assert_nil(inat_import.reload.importables,
               "URL mode should save nil importables (unknown until job runs)")
  end

  def test_superimporter_not_own_can_import_via_url_without_username
    user = users(:dick)
    assert(InatImport.super_importer?(user),
           "Test requires a super_importer fixture")
    url = "#{INAT_SITE_OBS_URL}?project_id=291058"

    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 3 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_url: url, import_others: "1", consent: 1 })

    assert_select("#estimated_count", true,
                  "Superimporter URL import without username should confirm")
  end

  def test_url_mode_estimate_merges_url_params
    user = users(:rolf)
    url = "#{INAT_SITE_OBS_URL}?project_id=291058"

    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 0 }.to_json)

    # Sentinel: return a distinct count only when project_id is included
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      with(query: hash_including("project_id" => "291058")).
      to_return(status: 200, body: { total_results: 7 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_username: "rolf_inat_user",
                   consent: 1 })

    assert_select("#estimated_count", "7",
                  "Estimate should include project_id from user URL")
  end

  def test_url_mode_estimate_mo_params_win_over_url_params
    user = users(:rolf)
    # URL supplies conflicting taxon_id and only_id; MO's values must win.
    # taxon_id=9999 is non-importable so it is stripped; MO's IMPORTABLE_IDS
    # and only_id=true should appear in the estimate request.
    url = "#{INAT_API_OBS_URL}?project_id=291058&taxon_id=9999&only_id=false"

    stub_request(:get, %r{api\.inaturalist\.org/v1/taxa}).
      to_return(status: 200, body: {
        total_results: 1,
        results: [{ id: 9999, ancestor_ids: [9999] }]
      }.to_json)
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 0 }.to_json)

    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      with(query: hash_including("taxon_id" => "47170,47685",
                                 "only_id" => "true")).
      to_return(status: 200, body: { total_results: 5 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_username: "rolf_inat_user",
                   consent: 1 })

    assert_select("#estimated_count", "5",
                  "MO taxon_id and only_id must override user-supplied values")
  end

  def test_url_mode_estimate_uses_user_supplied_importable_taxon_id
    user = users(:rolf)
    # taxon_id=54134 is a Fungi child — importable. The estimate must send
    # taxon_id=54134, not MO's IMPORTABLE_TAXON_IDS_ARG (47170,47685).
    url = "#{INAT_API_OBS_URL}?project_id=291058&taxon_id=54134"

    stub_request(:get, %r{api\.inaturalist\.org/v1/taxa}).
      to_return(status: 200, body: {
        total_results: 1,
        results: [{ id: 54_134,
                    ancestor_ids: [48_460, 47_170, 54_134] }]
      }.to_json)
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 0 }.to_json)

    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      with(query: hash_including("taxon_id" => "54134")).
      to_return(status: 200, body: { total_results: 3 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_username: "rolf_inat_user",
                   consent: 1 })

    assert_select("#estimated_count", "3",
                  "Importable user-supplied taxon_id should be used " \
                  "in the estimate, not replaced by IMPORTABLE_TAXON_IDS_ARG")
  end

  def test_url_mode_estimate_excludes_id_param
    user = users(:rolf)
    # URL supplies id=12345; PageParser drops it in URL mode, estimate must too.
    url = "#{INAT_API_OBS_URL}?project_id=291058&id=12345"

    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 0 }.to_json)

    # Returns 9 only when id is absent (i.e. not scoped to a specific obs).
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      with(query: hash_including("project_id" => "291058")).
      to_return(status: 200, body: { total_results: 9 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_username: "rolf_inat_user",
                   consent: 1 })

    assert_select("#estimated_count", "9",
                  "id param from URL must be excluded from the estimate")
  end

  def test_non_superuser_url_with_foreign_user_id_strips_user_id_from_estimate
    user = users(:rolf)
    # user_id is stripped for non-superimporters — iNat ORs user_id and
    # user_login, so a user-supplied user_id alongside the injected user_login
    # would return unexpected observations. The estimate must not include it.
    url = "#{INAT_SITE_OBS_URL}?place_id=1&user_id=someone_else"

    # Returns 5 for any request (user_id stripped; user_login injected by MO).
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 200, body: { total_results: 5 }.to_json)

    # Would return 99 if user_id leaked into the estimate request.
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      with(query: hash_including("user_id" => "someone_else")).
      to_return(status: 200, body: { total_results: 99 }.to_json)

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_username: "rolf_inat_user",
                   consent: 1 })

    assert_select("#estimated_count", "5",
                  "user_id must be stripped from the estimate request")
  end

  def test_url_params_preserved_through_confirm_round_trip
    user = users(:rolf)
    inat_import = inat_imports(:rolf_inat_import)
    normalized = "project_id=291058"

    login(user.login)
    post(:create,
         params: {
           confirmed: 1,
           inat_import_confirm: {
             inat_username: "rolf_inat_user",
             inat_ids: "",
             inat_url: normalized,
             import_all: "",
             consent: "1"
           }
         })

    assert_redirected_to(INAT_AUTHORIZATION_URL,
                         "Confirmed URL via superform params should auth")
    assert_equal(normalized, inat_import.reload.inat_url,
                 "inat_url should be saved from superform hidden field")
  end

  def test_estimate_422_surfaces_inat_error_message
    user = users(:rolf)
    url = "#{INAT_API_OBS_URL}?place_id=678910"
    inat_error = "Unknown place_id 678910"

    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return(status: 422,
                body: { error: inat_error, status: 422 }.to_json,
                headers: { "Content-Type" => "application/json" })

    login(user.login)
    post(:create,
         params: { inat_url: url, inat_username: "rolf_inat_user",
                   consent: 1 })

    assert_flash_text(
      /#{Regexp.escape(inat_error)}/,
      "Flash should surface iNat's error text instead of the generic " \
      "'Cannot communicate' message"
    )
    assert_select("input#inat_import_inat_url", true,
                  "Form should be reloaded, not the confirm page")
  end

  ########## Utilities

  def authorization_denial_callback_params
    { error: "access_denied",
      error_description:
        "The resource owner or authorization server denied the request." }
  end
end
