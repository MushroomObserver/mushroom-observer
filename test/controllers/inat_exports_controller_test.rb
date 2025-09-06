# frozen_string_literal: true

require("test_helper")

# test exporting Mushroom Observer Observations to iNaturalist
class InatExportsControllerTest < FunctionalTestCase
  include ActiveJob::TestHelper
  include Inat::Constants

  def test_new_inat_export_of_observation
    obs = observations(:coprinus_comatus_obs)
    user = obs.user

    login(user.login)
    get(:new, params: { id: obs.id })

    assert_response(:success)
    assert_form_action(action: :create, params: { mo_ids: [obs.id] })
    assert_select("input#inat_username", true,
                  "Form needs a field for inputting iNat username")
    assert_select("a[href=?]", observation_path(obs.id), text: :CANCEL.l)
  end

  def test_new_inat_export_of_obs_inat_username_prefilled
    obs = observations(:trusted_hidden)
    user = obs.user
    assert(user.inat_username.present?,
           "Test needs a user fixture with an inat_username")

    login(user.login)
    get(:new, params: { id: obs.id })

    assert_select(
      "input[name=?][value=?]", "inat_username", user.inat_username, true,
      "InatExport should pre-fill `inat_username` with user's inat_username"
    )
  end

  def test_new_inat_export_pending
    # Observation belongs to katrina, whose iNat export is busy Exporting
    obs = observations(:untrusted_hidden)
    user = obs.user

    login(user.login)
    get(:new, params: { id: obs.id })

    assert_flash_warning(
      "Should flash warning if user starts iNat export while another is running"
    )
    assert_redirected_to(
      observation_path(id: obs.id)
    )
  end

  def test_new_inat_export_of_observations_index
    skip("Awaiting an `Export to Inat` Action on Observations index")
    obs = observations(:coprinus_comatus_obs)
    user = obs.user

    login(user.login)
    get(:new, params: { id: obs.id })

    assert_response(:success)
    assert_form_action(action: :create)
    assert_select("input#inat_username", true,
                  "Form needs a field for inputting iNat username")
    assert_select("a[href=?]", observations_path, text: :CANCEL.l)
  end

  def test_create_inat_export
    obs = observations(:trusted_hidden)
    user = obs.user
    assert(user.inat_username.present?,
           "Test needs an obs whose user has an inat_username")
    params = { mo_ids: [obs.id], inat_username: user.inat_username }

    login(user.login)
    post(:create, params: params)

    assert_redirected_to(INAT_AUTHORIZATION_URL, allow_other_host: true)
  end

  def test_create_cancel_reset
    user = users(:ollie)
    export = inat_exports(:ollie_inat_export)
    assert(export.canceled?, "Test needs a canceled InatExport fixture")
    params = { mo_ids: [123], inat_username: user.inat_username }

    login(user.login)
    post(:create, params: params)

    assert_not(export.reload.canceled?,
               "`cancel` should be reset to false when starting an export")
  end

  def test_create_strip_inat_username
    export = inat_exports(:mary_inat_export)
    user = export.user

    stub_request(:any, INAT_AUTHORIZATION_URL)
    login(user.login)
    post(:create, params: { inat_username: export.inat_username })

    assert_equal(
      export.inat_username.strip, user.reload.inat_username,
      "It should strip leading/trailing whitespace from inat_username"
    )
  end

  def test_create_missing_username
    user = users(:rolf)
    id = "123"
    params = { mo_ids: [id] }

    login(user.login)
    post(:create, params: params)

    assert_flash_text(:inat_missing_username.l)
    assert_form_action(action: :create)
  end

  def test_create_observation_none_exportable
    user = observations(:imported_inat_obs).user
    params = { mo_ids: [], # blank because obs is non-exportable
               inat_username: "anything" }

    login(user.login)
    post(:create, params: params)

    assert_flash_text(:inat_export_no_exportables.l)
    assert_form_action(action: :create)
  end

  def test_create_assure_user_has_mo_api_key
    export = inat_exports(:mary_inat_export)
    user = export.user
    assert(APIKey.where(user: user, notes: MO_API_KEY_NOTES).none?,
           "Test needs user without an MO API key for iNat import/export")

    stub_request(:any, INAT_AUTHORIZATION_URL)
    login(user.login)
    post(:create, params: { inat_username: export.inat_username,
                            mo_ids: [observations(:minimal_unknown_obs).id] })

    assert(
      APIKey.where(user: user, notes: MO_API_KEY_NOTES).
             where.not(verified: nil).one?,
      "MO should assure user has personal verified API key for iNat imports"
    )
  end

  def test_create_authorization_request
    user = users(:rolf)
    inat_username = "rolf" # use different inat_username to test if it's updated
    export = inat_exports(:rolf_inat_export)
    assert_equal("Unstarted", export.state,
                 "Need a Unstarted inat_export fixture")
    assert_equal(0, export.total_exported_count.to_i,
                 "Test needs InatExport fixture without prior exports")
    inat_ids = "123,456,789"

    stub_request(:any, INAT_AUTHORIZATION_URL)
    login(user.login)

    assert_no_difference(
      "Observation.count",
      "Authorization request to iNat shouldn't create MO Observation(s)"
    ) do
      post(:create,
           params: { mo_ids: inat_ids, inat_username: inat_username })
    end

    assert_response(:redirect)
    assert_equal("Authorizing", export.reload.state,
                 "MO should be awaiting authorization from iNat")
    assert_equal(inat_username, export.inat_username,
                 "Failed to save InatExport.inat_username")

    # TODO: fix these tests, which are all related to the job tracker page.
    # assert_equal(inat_ids.split(",").length, export.exportables,
    #              "Failed to save InatExport.exportables")
    # assert_equal(
    #  InatExport.sum(:total_seconds) / InatExport.sum(:total_exported_count),
    #  export.avg_export_time
    # )
  end

  def test_authorization_response_denied
    skip("Awaiting implementation of :authorization_response action")
    login

    get(:authorization_response, params: AUTHORIZATION_DENIAL_CALLBACK_PARAMS)

    assert_redirected_to(observations_path)
    assert_flash_error
  end

  def test_import_authorized
    skip("Awaiting implementation of :authorization_response action")
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
    skip("Awaiting implementation of :authorization_response action")
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
    get(:authorization_response, params: AUTHORIZATION_DENIAL_CALLBACK_PARAMS)

    assert_blank(
      user.reload.inat_username,
      "User inat_username shouldn't change if user denies authorization to MO"
    )
  end

  def test_show
    skip("Awaiting implementation of Job, Tracker, and :show action")
    export = inat_exports(:rolf_inat_export)
    tracker = InatExportJobTracker.create(inat_export: export.id)

    login

    get(:show, params: { id: export.id, tracker_id: tracker.id })

    assert_response(:success)
  end
end
