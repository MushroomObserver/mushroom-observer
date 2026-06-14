# frozen_string_literal: true

require("test_helper")

module Inat::ImportAudit
  # Unit tests for the pure delta/parse helpers.
  class CompareTest < UnitTestCase
    include Compare

    def test_norm
      assert_equal("a b c", norm("  a\n b\t c "))
      assert_equal("", norm(nil))
    end

    def test_snapshot_field
      text = "User: joe\nObserved: 2024-01-01\nPlace: Here"
      assert_equal("joe", snapshot_field(text, "User"))
      assert_equal("2024-01-01", snapshot_field(text, "Observed"))
      assert_nil(snapshot_field(text, "Missing"))
    end

    def test_extra_note_keys_excludes_importer_keys
      obs = note_double(iNat_imported_data: "snap", Other: "x",
                        Substrate: "soil", Spore_Print: "white")
      extra = extra_note_keys(obs)
      assert_equal(%w[Substrate Spore_Print], extra.keys)
      assert_equal("soil", extra["Substrate"])
    end

    def test_extra_note_keys_blank
      assert_empty(extra_note_keys(note_double))
      assert_empty(extra_note_keys(Struct.new(:notes).new(nil)))
    end

    def test_other_residual_identical_is_empty
      assert_equal("", other_residual("same text", "same text"))
    end

    def test_other_residual_returns_mo_only_content
      assert_equal("extra mo note",
                   other_residual("a desc. extra mo note", "a desc."))
    end

    def test_other_residual_strips_field_slip_and_backlink
      mo = "Field slip: NEMF-123; https://mushroomobserver.org/obs/5"
      assert_equal("", other_residual(mo, ""))
    end

    def test_other_residual_strips_dated_previous_location
      mo = "Field slip: X; 2026-02-01: Previous location: Tompkins Co"
      assert_equal("", other_residual(mo, ""))
    end

    def test_other_residual_flags_a_real_edit
      # iNat keeps a typo MO corrected ("wring" -> "wrong").
      residual = other_residual("the surface is wrong", "the surface is wring")
      assert_includes(residual, "wrong")
    end

    private

    def note_double(**notes)
      Struct.new(:notes).new(notes)
    end
  end
end
