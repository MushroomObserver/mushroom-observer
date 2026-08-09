# frozen_string_literal: true

require("test_helper")

module Images
  class FieldSlipExtractsControllerTest < FunctionalTestCase
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

    def test_create_records_the_extract_and_redirects_to_review
      login_as_site_admin
      result = FieldSlip::Extractor::Result.new(
        provider: "gemini", model: "gemini-3.6-flash", raw: { "x" => 1 },
        fields: { "Collector" => "Scott Shapiro" }, confidence: {},
        template: "mo"
      )

      FieldSlip::Extractor.stub(:default, fake_extractor(result)) do
        post(:create, params: { image_id: @image.id })
      end

      assert_redirected_to(edit_image_field_slip_extract_path(@image.id))
      extract = FieldSlipExtract.find_by(image_id: @image.id)

      assert_equal("Scott Shapiro", extract.value_for("Collector"))
      assert_equal("gemini-3.6-flash", extract.model)
      # Stamped from the constant, not a literal: a read is only
      # attributable to the prompt that produced it if these agree.
      assert_equal(FieldSlip::Extractor::PROMPT_VERSION,
                   extract.prompt_version)
    end

    # A provider failure has to land as a flash, not a 500 -- the button
    # is one click and the network is not reliable.
    def test_create_reports_a_provider_failure
      login_as_site_admin

      FieldSlip::Extractor.stub(:default, failing_extractor) do
        post(:create, params: { image_id: @image.id })
      end

      assert_redirected_to(image_path(@image.id))
      assert_flash_error
    end

    def test_create_with_an_unknown_image_redirects
      login_as_site_admin

      post(:create, params: { image_id: -1 })

      assert_redirected_to(images_path)
      assert_flash_error
    end

    # ---------- edit ----------

    def test_edit_without_an_extract_redirects
      login_as_site_admin

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

    private

    def fake_extractor(result)
      extractor = Object.new
      extractor.define_singleton_method(:extract) { |_image, **| result }
      extractor
    end

    def failing_extractor
      extractor = Object.new
      extractor.define_singleton_method(:extract) do |_image, **|
        raise(FieldSlip::Extractor::Gemini::BadResponse.new("nope"))
      end
      extractor
    end
  end
end
