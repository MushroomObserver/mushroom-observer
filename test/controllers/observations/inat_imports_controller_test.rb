# frozen_string_literal: true

require "test_helper"

# test importing iNaturalist Observations to Mushroom Observer
module Observations
  # a duck type of API2::ImageAPI with enough attributes
  # to preventInatImportsController from throwing an error
  class MockImageAPI
    attr_reader :errors, :results

    def initialize(errors: [], results: [])
      @errors = errors
      @results = results
    end
  end

  class InatImportsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    SITE = Observations::InatImportsController::SITE
    REDIRECT_URI = Observations::InatImportsController::REDIRECT_URI
    API_BASE = Observations::InatImportsController::API_BASE

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

      assert_flash_text(:inat_no_imports_designated.l)
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
                 consent: 1 }
      login
      assert_no_difference("Observation.count",
                           "Imported a previously imported iNat obs") do
        post(:create, params: params)
      end

      # NOTE: 2024-09-04 jdc
      # I'd prefer that the flash include links to both obss,
      # and that this (or another) assertion check for that.
      # At the moment, it's taking too long to figure out how.
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
      user = users(:rolf)
      inat_username = " rolf "
      inat_import = inat_imports(:rolf_inat_import)
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

      assert_response(:redirect)
      assert_equal(
        "rolf", inat_import.reload.inat_username,
        "It should strip leading/trailing whitespace from inat_username"
      )
    end

    def test_create_authorization_request
      user = users(:rolf)
      inat_username = "rolf"
      inat_import = inat_imports(:rolf_inat_import)
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

      assert_response(:redirect)
      assert_equal("Authorizing", inat_import.reload.state,
                   "MO should be awaiting authorization from iNat")
      assert_equal(inat_username, inat_import.inat_username,
                   "Failed to save InatImport.inat_username")
    end

    def test_authorization_response_denied
      inat_authorization_callback_params =
        { error: "access_denied",
          error_description: "The resource owner or authorization server " \
                             "denied the request." }
      login

      get(:authorization_response, params: inat_authorization_callback_params)

      assert_redirected_to(observations_path)
      assert_flash_error
    end

    def test_import_authorized
      user = users(:rolf)
      inat_import = inat_imports(:rolf_inat_import)

      # Blank id_list in order to prevent importing any observations
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
      assert_flash_success
      tracker = InatImportJobTracker.find_by(inat_import: inat_import)
      assert_redirected_to(inat_import_job_tracker_path(tracker.id))
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
  end
end
