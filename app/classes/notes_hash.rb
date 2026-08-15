# frozen_string_literal: true

# The dynamic-keyed notes Hash shared across Observation, Occurrence,
# FieldSlip, and species-list write-in (keys drawn from
# User#notes_template_parts plus a fixed "Other" catch-all, values are
# strings). Normalizes keys to use underscores rather than spaces and
# to be case-insensitive for setting, but the key used is the first
# one that gets assigned.
#
# Wraps its underlying Hash BY REFERENCE, not by copy -- this is load-
# bearing: Rails' `serialize :notes, coder: YAML` (Observation#notes)
# detects an in-place `#[]=`/`#delete` on the object this class wraps
# by re-serializing and comparing against the original column value,
# so API2::ObservationAPI#update_notes_fields's `obs.notes[key] = val`
# / `obs.notes.delete(key)` -- with no separate `obs.notes = ...`
# reassignment -- still gets picked up by `obs.save`. Never dup the
# hash in `initialize` or `#[]=`.
class NotesHash
  extend Forwardable

  def_delegators :@hash, :[], :keys, :values, :each, :each_pair, :map, :select,
                 :reject, :empty?, :size, :length, :to_s, :inspect, :except,
                 :key?, :has_key?, :include?, :fetch, :dig, :merge, :delete,
                 :clear, :each_key, :each_value, :transform_values, :==,
                 :value_merge!, :compact_blank!, :each_with_object, :to_unsafe_h

  def initialize(hash = {})
    @hash = hash.is_a?(Hash) ? hash : {}
  end

  # Builds from a raw params value (an ActionController::Parameters,
  # possibly nil/blank) -- the `.to_unsafe_h.symbolize_keys` conversion
  # this dynamic key set needs (keys aren't fixed Strong Params
  # attributes) was duplicated across ObservationsController::New,
  # ObservationsController::SharedFormMethods, and
  # SpeciesLists::WriteInController.
  def self.from_params(raw)
    return new(Observation.no_notes) if raw.blank?

    new(raw.to_unsafe_h.symbolize_keys)
  end

  def []=(key, value)
    normalized_key = key.to_s.tr(" ", "_")
    comparison_key = normalized_key.downcase

    existing_key = @hash.keys.find do |existing|
      existing.to_s.downcase == comparison_key
    end

    if existing_key
      @hash[existing_key] = value
    else
      @hash[normalized_key.to_sym] = value
    end
  end

  # The underlying Hash, by reference -- e.g. for assigning back to
  # Observation#notes=, or merging into it (FieldSlip::Extractor::
  # Applier#assign_notes).
  def to_h
    @hash
  end

  alias to_hash to_h
end
