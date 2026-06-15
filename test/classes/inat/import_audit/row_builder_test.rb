# frozen_string_literal: true

require("test_helper")

module Inat::ImportAudit
  # Tests the per-observation delta / ambiguity logic. `raw` is passed
  # directly, so these don't hit the iNat API.
  class RowBuilderTest < UnitTestCase
    def setup
      @builder = RowBuilder.new(source: sources(:inaturalist))
    end

    def test_clean_import_has_no_delta
      row = build(notes: snapshot_notes("a desc"), raw: inat_raw("a desc"))
      assert_equal("ok", row[:inat_status])
      assert(row[:snapshot_present])
      assert_equal("", row[:delta_note_keys])
      assert_not(row[:has_delta])
      assert_not(row[:ambiguous])
    end

    def test_extra_note_key_is_a_clean_delta
      notes = snapshot_notes("a desc").merge(Substrate: "soil")
      row = build(notes: notes, raw: inat_raw("a desc"))
      assert_equal("Substrate", row[:delta_note_keys])
      assert(row[:has_delta])
      assert_not(row[:ambiguous])
    end

    def test_other_residual_is_ambiguous
      notes = snapshot_notes("a desc").merge(Other: "a desc plus my own note")
      row = build(notes: notes, raw: inat_raw("a desc"))
      assert_includes(row[:other_residual], "my own note")
      assert(row[:ambiguous])
    end

    def test_image_count_mismatch_is_ambiguous
      row = build(notes: snapshot_notes(""), raw: inat_raw("", photos: 3))
      assert_equal(false, row[:images_count_match])
      assert(row[:ambiguous])
    end

    def test_not_found_when_raw_missing
      row = build(notes: snapshot_notes("x"), raw: nil)
      assert_equal("not_found", row[:inat_status])
    end

    def test_fetch_error_flag
      row = @builder.call(observation(snapshot_notes("x")), nil,
                          fetch_failed: true)
      assert_equal("fetch_error", row[:inat_status])
    end

    def test_missing_snapshot_with_source_is_ambiguous
      row = build(notes: { Other: "x" }, raw: inat_raw("x", photos: 0))
      assert_not(row[:snapshot_present])
      assert(row[:ambiguous])
    end

    def test_collector_user_matching_uploader_is_not_a_diff
      users(:rolf).update!(inat_username: "rolf_inat")
      obs = collector_obs(user_login: "rolf_inat",
                          collector_user_id: users(:rolf).id)
      assert_not(@builder.call(obs, inat_raw("x"))[:collector_differs])
    end

    def test_collector_user_differing_from_uploader_is_a_diff
      users(:rolf).update!(inat_username: "rolf_inat")
      obs = collector_obs(user_login: "rolf_inat",
                          collector_user_id: users(:mary).id)
      assert(@builder.call(obs, inat_raw("x"))[:collector_differs])
    end

    def test_free_text_collector_matching_uploader_is_not_a_diff
      obs = collector_obs(user_login: "joe", collector: "joe")
      assert_not(@builder.call(obs, inat_raw("x"))[:collector_differs])
    end

    def test_free_text_collector_naming_another_person_is_a_diff
      obs = collector_obs(user_login: "bdthomas", collector: "Daniel Oshiro")
      assert(@builder.call(obs, inat_raw("x"))[:collector_differs])
    end

    private

    def build(notes:, raw:)
      @builder.call(observation(notes), raw)
    end

    def collector_obs(user_login:, **attrs)
      Observation.new({ external_id: "999",
                        notes: { iNat_imported_data: "User: #{user_login}",
                                 Other: "x" } }.merge(attrs))
    end

    def observation(notes)
      Observation.new(external_id: "999", notes: notes)
    end

    def snapshot_notes(description)
      { iNat_imported_data: "User: joe\nObserved: 2024-01-01",
        Other: description }
    end

    def inat_raw(description, photos: 0)
      { taxon: { name: "Boletus", rank: "species", ancestor_ids: [] },
        description: description,
        user: { login: "joe" },
        observation_photos: Array.new(photos) { {} } }
    end
  end
end
