# frozen_string_literal: true

require("test_helper")

class NotesHashTest < UnitTestCase
  def test_initialize_wraps_a_hash
    notes = NotesHash.new(Cap: "red")

    assert_equal("red", notes[:Cap])
  end

  def test_initialize_defaults_non_hash_to_empty
    assert_equal({}, NotesHash.new(nil).to_h)
    assert_equal({}, NotesHash.new("not a hash").to_h)
    assert_equal({}, NotesHash.new.to_h)
  end

  # Regression: `hash.is_a?(Hash)` alone is false for a NotesHash
  # argument, which used to silently drop its contents into an empty
  # {} instead of unwrapping it.
  def test_initialize_unwraps_another_notes_hash_by_reference
    original = NotesHash.new(Cap: "red")
    wrapped = NotesHash.new(original)

    assert_equal({ Cap: "red" }, wrapped.to_h)

    wrapped[:Cap] = "brown"
    assert_equal("brown", original[:Cap],
                 "should unwrap the same underlying Hash, not a copy")
  end

  def test_bracket_set_normalizes_new_key
    notes = NotesHash.new
    notes["Cap Color"] = "red"

    assert_equal("red", notes[:Cap_Color])
  end

  def test_bracket_set_reuses_existing_key_case_insensitively
    notes = NotesHash.new(Cap_Color: "red")
    notes["cap_color"] = "brown"

    assert_equal({ Cap_Color: "brown" }, notes.to_h)
  end

  # Load-bearing: Rails' `serialize :notes, coder: YAML`
  # (Observation#notes) detects an in-place mutation by re-serializing
  # the CURRENT value and comparing it to the original column value --
  # that only works if NotesHash wraps the same Hash object it was
  # constructed with, not a copy. API2::ObservationAPI#
  # update_notes_fields relies on exactly this (`obs.notes[key] =
  # val` / `obs.notes.delete(key)`, with no separate `obs.notes =`
  # reassignment).
  def test_wraps_hash_by_reference_not_copy
    original = { Cap: "red" }
    notes = NotesHash.new(original)

    notes[:Cap] = "brown"
    assert_equal("brown", original[:Cap])

    notes.delete(:Cap)
    assert_not(original.key?(:Cap))
  end

  def test_delegated_methods
    notes = NotesHash.new(Cap: "red", Other: "")

    assert_equal([:Cap, :Other], notes.keys)
    assert(notes.key?(:Cap))
    assert_not(notes.key?(:Gills))
    assert_equal("red", notes.fetch(:Cap))
    collected = {}
    notes.each { |key, value| collected[key] = value }
    assert_equal({ Cap: "red", Other: "" }, collected)
  end

  def test_equality_delegates_to_underlying_hash
    assert_equal({}, NotesHash.new)
    assert_equal({ Cap: "red" }, NotesHash.new(Cap: "red"))
  end

  def test_to_h_and_to_hash_return_the_underlying_hash
    notes = NotesHash.new(Cap: "red")

    assert_equal({ Cap: "red" }, notes.to_h)
    assert_equal({ Cap: "red" }, notes.to_hash)
  end

  def test_from_params_converts_action_controller_parameters
    raw = ActionController::Parameters.new(Cap: "red", Other: "")
    notes = NotesHash.from_params(raw)

    assert_instance_of(NotesHash, notes)
    assert_equal({ Cap: "red", Other: "" }, notes.to_h)
  end

  def test_from_params_returns_empty_for_blank_input
    assert_equal(Observation.no_notes, NotesHash.from_params(nil).to_h)
    assert_equal(
      Observation.no_notes,
      NotesHash.from_params(ActionController::Parameters.new).to_h
    )
  end
end
