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
# so several callers mutate `obs.notes` directly (`obs.notes[key] =
# val`, `.delete(key)`, `.value_merge!(...)`, `.compact_blank!`) with
# no separate `obs.notes = ...` reassignment, relying on that mutation
# still being picked up by a later `obs.save`/`obs.save!`:
# API2::ObservationAPI#update_notes_fields, FieldSlipsController::
# ObservationHandling#update_observation_fields, and
# ObservationsController::ProjectAliases#resolve_id_by_note/
# #resolve_other_codes_note. Never dup the hash in `initialize` or
# `#[]=`.
#
# Caveat: this only holds while the underlying column already holds a
# real Hash. `Observation#notes` returns a fresh, disconnected
# `Observation.no_notes` (a bare `{}`, not wrapped) whenever the
# stored value isn't a Hash (i.e. the column is nil) -- two separate
# calls to `obs.notes` in that state return two different objects, so
# an in-place mutation followed by `obs.save` silently loses the
# write. Pre-existing behavior (same gap existed under this class's
# predecessor, NormalizedHash), not something this class can fix on
# its own since it never sees the nil case at all.
class NotesHash
  extend Forwardable

  def_delegators :@hash, :[], :keys, :values, :each, :each_pair, :map, :select,
                 :reject, :empty?, :size, :length, :to_s, :inspect, :except,
                 :key?, :has_key?, :include?, :fetch, :dig, :merge, :delete,
                 :clear, :each_key, :each_value, :transform_values, :==,
                 :value_merge!, :compact_blank!, :each_with_object, :to_unsafe_h

  # Unwraps a NotesHash argument (by reference, via #to_h) rather than
  # silently discarding it -- `hash.is_a?(Hash)` alone would be false
  # for a NotesHash, dropping its contents into an empty {}.
  def initialize(hash = {})
    @hash = if hash.is_a?(NotesHash)
              hash.to_h
            elsif hash.is_a?(Hash)
              hash
            else
              {}
            end
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
