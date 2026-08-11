# frozen_string_literal: true

require("test_helper")

module Images
  class FieldSlipExtractsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    def setup
      super
      @obs = observations(:minimal_unknown_obs)
      @image = images(:in_situ_image)
      @obs.images << @image unless @obs.images.include?(@image)
      @project = projects(:eol_project)
    end

    def record_extract(fields: {}, confidence: {}, template: "mo")
      FieldSlipExtract.record(
        image: @image, user: rolf, prompt_version: "1",
        result: FieldSlip::Extractor::Result.new(
          provider: "g", model: "m", raw: {}, fields: fields,
          confidence: confidence, template: template
        )
      )
    end

    def login_as_site_admin
      login("rolf")
      make_admin
    end

    def join_project_as_admin(user)
      @project.observations << @obs unless @project.observations.include?(@obs)
      login(user.login)
    end

    # ---------- permissions ----------

    def test_edit_requires_login
      record_extract(fields: { "Collector" => "A" })

      get(:edit, params: { image_id: @image.id })

      assert_redirected_to(new_account_login_path)
    end

    def test_edit_refused_for_an_ordinary_user
      record_extract(fields: { "Collector" => "A" })
      login("katrina")

      get(:edit, params: { image_id: @image.id })

      assert_redirected_to(image_path(@image.id))
      assert_flash_error
    end

    def test_edit_allowed_for_a_site_admin
      record_extract(fields: { "Collector" => "A" })
      login_as_site_admin

      get(:edit, params: { image_id: @image.id })

      assert_response(:success)
    end

    # A foray's own organizers are the people who can tell whether a
    # slip was transcribed right.
    def test_edit_allowed_for_a_project_admin
      record_extract(fields: { "Collector" => "A" })
      join_project_as_admin(mary)

      assert(@project.is_admin?(mary), "premise: mary administers it")
      get(:edit, params: { image_id: @image.id })

      assert_response(:success)
    end

    def test_create_refused_for_an_ordinary_user
      login("katrina")

      post(:create, params: { image_id: @image.id })

      assert_redirected_to(image_path(@image.id))
    end

    # ---------- create ----------

    # The provider call runs in a job now (see ExtractFieldSlipJob);
    # the button's request just queues it and lands on the review page,
    # which shows the pending state.
    def test_create_enqueues_the_read_and_redirects_to_review
      login_as_site_admin

      assert_enqueued_with(job: ExtractFieldSlipJob,
                           args: [@image.id, rolf.id]) do
        post(:create, params: { image_id: @image.id })
      end

      assert_redirected_to(edit_image_field_slip_extract_path(@image.id))
      extract = FieldSlipExtract.find_by(image_id: @image.id)

      assert(extract.pending?, "the review page needs a status to show")
    end

    def test_create_with_an_unknown_image_redirects
      login_as_site_admin

      post(:create, params: { image_id: -1 })

      assert_redirected_to(images_path)
      assert_flash_error
    end

    # ---------- edit ----------

    # No extract renders the not-scanned-yet page with the scan button
    # -- the landing spot for the no-slip-detected flash, and how a
    # zbar-missed slip photo gets read at all. No polling: nothing is
    # running until the button is pressed.
    def test_edit_without_an_extract_offers_the_scan
      login_as_site_admin

      get(:edit, params: { image_id: @image.id })

      assert_response(:success)
      assert_select(
        "form[action='#{image_field_slip_extract_path(@image.id)}'] " \
        "button[type='submit']"
      )
      assert_select("[data-controller='reload-poll']", count: 0)
    end

    def test_edit_shows_a_pending_read_with_self_refresh
      FieldSlipExtract.start!(image: @image, user: rolf)
      login_as_site_admin

      get(:edit, params: { image_id: @image.id })

      assert_response(:success)
      assert_select("[data-controller='reload-poll']")
    end

    def test_edit_shows_a_failed_read_with_a_retry_button
      FieldSlipExtract.fail!(image: @image, user: rolf, error: "quota")
      login_as_site_admin

      get(:edit, params: { image_id: @image.id })

      assert_response(:success)
      assert_select(".alert-danger", text: /quota/)
      assert_select(
        "form[action='#{image_field_slip_extract_path(@image.id)}']"
      )
      assert_select("[data-controller='reload-poll']", count: 0)
    end

    # The observation-create redirect arrives before the QR jobs have
    # attached anything; `await=1` is what makes an extract-less page
    # wait instead of bouncing.
    # The create redirect appends await=1; the page renders the same
    # meaningful state with or without it.
    def test_edit_with_await_param_renders_the_same_page
      login_as_site_admin

      get(:edit, params: { image_id: @image.id, await: 1 })

      assert_response(:success)
    end

    # ...and can land before the observation is even in its project,
    # when `permitted?` has nothing to check against. Waiting on your
    # own upload needs only ownership; the review form still needs
    # project admin-ship.
    def test_owner_may_wait_on_their_own_upload_before_project_filing
      owner = @obs.user
      login(owner.login)

      assert_not(
        FieldSlipExtract.permitted?(image: @image.reload, user: owner),
        "premise: ownership alone, no project admin-ship"
      )

      FieldSlipExtract.start!(image: @image, user: owner)

      get(:edit, params: { image_id: @image.id })

      assert_response(:success)
      assert_select("[data-controller='reload-poll']")
    end

    def test_owner_alone_may_not_review_a_completed_extract
      owner = @obs.user
      login(owner.login)

      assert_not(
        FieldSlipExtract.permitted?(image: @image.reload, user: owner),
        "premise: ownership alone, no project admin-ship"
      )

      record_extract(fields: { "Collector" => "A" })

      get(:edit, params: { image_id: @image.id })

      assert_redirected_to(image_path(@image.id))
      assert_flash_error
    end

    def test_edit_renders_the_rows_and_the_name_section
      record_extract(fields: { "Collector" => "Scott Shapiro",
                               "ID" => "Boletus" })
      login_as_site_admin

      get(:edit, params: { image_id: @image.id })

      assert_select("input[name='value[Collector]'][value='Scott Shapiro']")
      assert_select("input[name='use[Collector]']")
      assert_select("[name='value[ID]']")
      assert_select("#field_slip_extract_name")
    end

    # ---------- update ----------

    def test_update_applies_only_ticked_fields
      record_extract(fields: { "Collector" => "Scott Shapiro",
                               "Substrate" => "wood" })
      login_as_site_admin

      put(:update, params: { image_id: @image.id,
                             use: { "Collector" => "1", "Substrate" => "0" },
                             value: { "Collector" => "Scott Shapiro",
                                      "Substrate" => "wood" } })

      @obs.reload

      assert_equal("Scott Shapiro", @obs.collector)
      assert_nil(@obs.notes[:Substrate])
      assert_redirected_to(permanent_observation_path(@obs.id))
    end

    # The reviewer's edit wins over what the model read: the extract is
    # a starting point, the form is the decision.
    def test_update_saves_the_edited_value_not_the_extracted_one
      record_extract(fields: { "Collector" => "Scott Shapior" })
      login_as_site_admin

      put(:update, params: { image_id: @image.id,
                             use: { "Collector" => "1" },
                             value: { "Collector" => "Scott Shapiro" } })

      assert_equal("Scott Shapiro", @obs.reload.collector)
    end

    def test_update_without_any_ticks_changes_nothing
      record_extract(fields: { "Collector" => "Scott Shapiro" })
      was = @obs.collector
      login_as_site_admin

      put(:update, params: { image_id: @image.id })

      assert_equal_even_if_nil(was, @obs.reload.collector)
      assert_redirected_to(permanent_observation_path(@obs.id))
    end

    # The flag rides along as a top-level param, the same shape the
    # observation form uses for the same decision.
    def test_update_stores_a_flagged_code_as_an_inat_link
      record_extract(fields: { "Other Codes" => "386717373" })
      login_as_site_admin

      put(:update, params: { image_id: @image.id, inat: "1",
                             use: { "Other Codes" => "1" },
                             value: { "Other Codes" => "386717373" } })

      assert_equal(FieldSlipNotesBuilder.inat_link("386717373"),
                   @obs.reload.notes[:Other_Codes])
    end

    def test_update_stores_an_unflagged_code_verbatim
      record_extract(fields: { "Other Codes" => "386717373" })
      login_as_site_admin

      put(:update, params: { image_id: @image.id, inat: "0",
                             use: { "Other Codes" => "1" },
                             value: { "Other Codes" => "386717373" } })

      assert_equal("386717373", @obs.reload.notes[:Other_Codes])
    end

    # A dbg extract reviews and saves through its own field labels --
    # the name lives in "Species", the iNat id in "iNaturalist", and
    # the coordinates land as a pair.
    def test_update_applies_a_dbg_extract
      record_extract(template: "dbg",
                     fields: { "Species" => "Coprinus comatus",
                               "Latitude" => "38.8703",
                               "Longitude" => "-105.0442",
                               "iNaturalist" => "10:29 388879492" })
      before = @obs.namings.count
      login_as_site_admin

      put(:update,
          params: { image_id: @image.id, inat: "1",
                    use: { "Species" => "1", "Latitude" => "1",
                           "Longitude" => "1", "iNaturalist" => "1" },
                    value: { "Species" => "Coprinus comatus",
                             "Latitude" => "38.8703",
                             "Longitude" => "-105.0442",
                             "iNaturalist" => "10:29 388879492" } })

      @obs.reload

      assert_equal(before + 1, @obs.namings.count)
      assert_in_delta(38.8703, @obs.lat)
      assert_in_delta(-105.0442, @obs.lng)
      link = FieldSlipNotesBuilder.inat_link("388879492")

      assert_equal("#{link} (10:29)", @obs.notes[:iNaturalist])
      assert_redirected_to(permanent_observation_path(@obs.id))
    end

    def test_update_proposes_a_ticked_known_name
      record_extract(fields: { "ID" =>
                               "Coprinus comatus" })
      before = @obs.namings.count
      login_as_site_admin

      put(:update, params: { image_id: @image.id, use: { "ID" => "1" },
                             value: { "ID" => "Coprinus comatus" } })

      assert_equal(before + 1, @obs.reload.namings.count)
      assert_redirected_to(permanent_observation_path(@obs.id))
    end

    def test_update_leaves_an_unticked_name_alone
      record_extract(fields: { "ID" =>
                               "Coprinus comatus" })
      before = @obs.namings.count
      login_as_site_admin

      put(:update, params: { image_id: @image.id, use: { "ID" => "0" },
                             value: { "ID" => "Coprinus comatus" } })

      assert_equal(before, @obs.reload.namings.count)
    end

    # An unrecognized name comes back for confirmation rather than being
    # created off a machine reading.
    def test_update_asks_before_creating_an_unknown_name
      record_extract(fields: { "ID" =>
                               "Lumpy Bracket" })
      names_before = Name.count
      login_as_site_admin

      put(:update, params: { image_id: @image.id, use: { "ID" => "1" },
                             value: { "ID" => "Lumpy Bracket" } })

      assert_response(:success)
      assert_equal(names_before, Name.count)
      assert_flash_warning
    end

    # The other fields land on the first pass, so confirming the name
    # does not mean re-doing the rest.
    def test_update_applies_fields_even_when_the_name_needs_approval
      record_extract(fields: { "Collector" => "Scott Shapiro",
                               "ID" =>
                               "Lumpy Bracket" })
      login_as_site_admin

      put(:update, params: { image_id: @image.id,
                             use: { "Collector" => "1", "ID" => "1" },
                             value: { "Collector" => "Scott Shapiro",
                                      "ID" => "Lumpy Bracket" } })

      assert_equal("Scott Shapiro", @obs.reload.collector)
    end

    # A placeholder is no opinion, not a name to create: the save must
    # complete rather than bouncing to a confirmation page whose
    # feedback panel would render empty.
    def test_update_completes_when_the_id_is_a_placeholder
      record_extract(fields: { "ID" =>
                               "unknown" })
      login_as_site_admin

      put(:update, params: { image_id: @image.id, use: { "ID" => "1" },
                             value: { "ID" => "unknown" } })

      assert_redirected_to(permanent_observation_path(@obs.id))
    end

    def test_update_creates_the_name_once_approved
      record_extract(fields: { "ID" =>
                               "Lumpysomething bracketii" })
      names_before = Name.count
      login_as_site_admin

      put(:update, params: { image_id: @image.id, use: { "ID" => "1" },
                             value: { "ID" => "Lumpysomething bracketii" },
                             approved_name: "Lumpysomething bracketii" })

      assert_operator(Name.count, :>, names_before)
      assert_redirected_to(permanent_observation_path(@obs.id))
    end

    def test_update_without_an_extract_redirects
      login_as_site_admin

      put(:update, params: { image_id: @image.id })

      assert_redirected_to(image_path(@image.id))
    end

    # ---------- attaching the ticked code ----------

    def test_update_attaches_a_ticked_code_to_a_slipless_observation
      @obs.update!(occurrence: nil)
      record_extract(fields: { "Field Slip Code" => "OPEN-0219" })
      login_as_site_admin

      put(:update, params: { image_id: @image.id,
                             use: { "Field Slip Code" => "1" },
                             value: { "Field Slip Code" => "OPEN-0219" } })

      assert_equal("OPEN-0219", @obs.reload.field_slip.code)
      assert_includes(projects(:open_membership_project).observations.reload,
                      @obs)
    end

    # A pre-existing spare slip gets "attached", not "created".
    def test_update_attaching_an_existing_spare_slip_says_attached
      @obs.update!(occurrence: nil)
      FieldSlip.find_or_create_by_code("OPEN-0219", @obs.user)
      record_extract(fields: { "Field Slip Code" => "OPEN-0219" })
      login_as_site_admin

      put(:update, params: { image_id: @image.id,
                             use: { "Field Slip Code" => "1" },
                             value: { "Field Slip Code" => "OPEN-0219" } })

      assert_equal("OPEN-0219", @obs.reload.field_slip.code)
      assert_flash([[:field_slip_attached, { code: "OPEN-0219" }],
                    :field_slip_extract_saved])
    end

    # The reviewer's edit wins here too: a misread code gets corrected
    # in the box and the corrected one attaches.
    def test_update_attaches_the_edited_code_not_the_read_one
      @obs.update!(occurrence: nil)
      record_extract(fields: { "Field Slip Code" => "OPEN-9999" })
      login_as_site_admin

      put(:update, params: { image_id: @image.id,
                             use: { "Field Slip Code" => "1" },
                             value: { "Field Slip Code" => "OPEN-0220" } })

      assert_equal("OPEN-0220", @obs.reload.field_slip.code)
    end

    # An in-use code is the "second observation of the same collection"
    # case (a recorder re-photographing an already-used slip): saving
    # the review joins the slip's occurrence, and the newly reviewed
    # observation becomes its primary.
    def test_update_with_an_in_use_code_joins_the_occurrence
      @obs.update!(occurrence: nil)
      other = observations(:coprinus_comatus_obs)
      other.update!(occurrence: nil)
      slip = FieldSlip.find_or_create_by_code("OPEN-0500", other.user)
      other.field_slip = slip
      other.save!
      record_extract(fields: { "Field Slip Code" => "OPEN-0500" })
      login_as_site_admin

      put(:update, params: { image_id: @image.id,
                             use: { "Field Slip Code" => "1" },
                             value: { "Field Slip Code" => "OPEN-0500" } })

      @obs.reload

      assert_equal(slip.reload.occurrence, @obs.occurrence)
      assert_equal(@obs.id, @obs.occurrence.primary_observation_id)
    end

    def test_update_warns_when_the_ticked_code_cannot_attach
      @obs.update!(occurrence: nil)
      other = observations(:coprinus_comatus_obs)
      other.update!(occurrence: nil)
      slip = FieldSlip.find_or_create_by_code("OPEN-0501", other.user)
      other.field_slip = slip
      other.save!
      record_extract(fields: { "Field Slip Code" => "OPEN-0501",
                               "Collector" => "A. Recorder" })
      login_as_site_admin

      original = Occurrence::MAX_OBSERVATIONS
      Occurrence.send(:remove_const, :MAX_OBSERVATIONS)
      Occurrence.const_set(:MAX_OBSERVATIONS, 1)

      put(:update, params: { image_id: @image.id,
                             use: { "Field Slip Code" => "1",
                                    "Collector" => "1" },
                             value: { "Field Slip Code" => "OPEN-0501",
                                      "Collector" => "A. Recorder" } })

      assert_nil(@obs.reload.occurrence)
      assert_flash_warning
      # The failed link never blocks the rest of the save.
      assert_equal("A. Recorder", @obs.collector)
    ensure
      Occurrence.send(:remove_const, :MAX_OBSERVATIONS)
      Occurrence.const_set(:MAX_OBSERVATIONS, original)
    end

    # The reported bug: the join decision at slip-attach time ran
    # against the create form's default date and locality, silently
    # keeping the observation out of its slip's project -- and the
    # review then fixed exactly those fields. Re-evaluating after the
    # apply joins the project.
    def test_update_joins_the_slips_project_once_constraints_are_met
      project = projects(:open_membership_project)
      project.update!(location: locations(:albion),
                      start_date: Date.parse("2026-07-30"),
                      end_date: Date.parse("2026-08-02"))
      project.join(@obs.user)
      @obs.update!(occurrence: nil)
      slip = FieldSlip.find_or_create_by_code("OPEN-0950", @obs.user)
      @obs.field_slip = slip
      @obs.save!

      assert(project.violates_constraints?(@obs),
             "premise: pre-review data violates the constraints")
      assert_not_includes(project.observations, @obs)

      record_extract(fields: { "Date" => "2026-08-01",
                               "Location" => locations(:albion).name })
      login_as_site_admin

      put(:update,
          params: { image_id: @image.id,
                    use: { "Date" => "1", "Location" => "1" },
                    value: { "Date" => "2026-08-01",
                             "Location" => locations(:albion).name } })

      assert_includes(project.observations.reload, @obs.reload)
      assert_flash_success
    end

    def test_update_warns_when_the_review_still_violates_constraints
      project = projects(:open_membership_project)
      project.update!(location: locations(:albion),
                      start_date: Date.parse("2026-07-30"),
                      end_date: Date.parse("2026-08-02"))
      project.join(@obs.user)
      @obs.update!(occurrence: nil)
      slip = FieldSlip.find_or_create_by_code("OPEN-0951", @obs.user)
      @obs.field_slip = slip
      @obs.save!
      record_extract(fields: { "Collector" => "A. W. Wilson" })
      login_as_site_admin

      put(:update, params: { image_id: @image.id,
                             use: { "Collector" => "1" },
                             value: { "Collector" => "A. W. Wilson" } })

      assert_not_includes(project.observations.reload, @obs.reload)
      assert_flash_warning
    end

    def test_update_never_moves_a_linked_observation
      slip = FieldSlip.find_or_create_by_code("OPEN-0800", @obs.user)
      @obs.update!(occurrence: nil)
      @obs.field_slip = slip
      @obs.save!
      record_extract(fields: { "Field Slip Code" => "OPEN-0219" })
      login_as_site_admin

      put(:update, params: { image_id: @image.id,
                             use: { "Field Slip Code" => "1" },
                             value: { "Field Slip Code" => "OPEN-0219" } })

      assert_equal("OPEN-0800", @obs.reload.field_slip.code)
    end
  end
end
