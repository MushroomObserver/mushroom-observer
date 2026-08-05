# frozen_string_literal: true

class FieldSlip
  # Machine-reads a field slip photo into MO's own field set.
  #
  # `Extractor.for(:gemini)` returns a provider adapter; every adapter
  # answers `#extract(image, context:)` with an `Extractor::Result`, so
  # swapping providers -- or A/B-ing a new one against Gemini -- touches
  # nothing but this registry. An adapter owns its own request and
  # response parsing, and is asked -- through the shared `Prompt` -- for
  # values keyed by the `FIELDS` labels below. Where each label lands on
  # the Observation is `FIELDS`' business and `Applier`'s, so a new
  # provider never restates the mapping.
  module Extractor
    PROVIDERS = { gemini: "FieldSlip::Extractor::Gemini" }.freeze

    # Bump when the prompt changes in a way that could change results.
    # Stored on the extract so a stale read is identifiable later --
    # which only works if this actually moves, so treat editing
    # `Prompt` and bumping this as one act.
    #
    #   1  initial
    #   2  user aliases transcribed rather than expanded, so "dcs" stays
    #      resolvable to a User (extracts at v1 may hold an expanded
    #      display name that resolves to nobody)
    #   3  an image with no slip in it answers slip_present false and
    #      all-null fields (extracts at v2 or earlier may hold values
    #      invented from the prompt's own alias tables); a null that
    #      was written but could not be read is listed in `unreadable`,
    #      separating it from a box the collector left empty
    PROMPT_VERSION = "3"

    # The slip's fields, in the order they appear on the printed form,
    # mapped to where each one lands on the Observation. `nil` means the
    # value is reviewed but not saved directly: the code is a
    # cross-check against the attached slip, and the ID becomes a
    # proposed naming rather than a column.
    FIELDS = {
      "Field Slip Code" => nil,
      "Collector" => :collector,
      "Date" => :when,
      "Location" => :place_name,
      "Notes" => :"notes.Other",
      "Odor/Taste" => :"notes.Odor/Taste",
      "Trees/Shrubs" => :"notes.Trees/Shrubs",
      "Substrate" => :"notes.Substrate",
      "Habit" => :"notes.Habit",
      "ID" => nil,
      "ID By" => :"notes.Field_Slip_ID_By",
      "Other Codes" => :"notes.Other_Codes",
      "MycoMap Voucher Number" => :"notes.MycoMap_Voucher_Number"
    }.freeze

    # The slip's ID, which has no target column: it becomes a proposed
    # naming, not an attribute. Editable all the same, and through a
    # name autocompleter rather than a plain box -- what collectors
    # write is often a common name ("Lumpy Bracket") or a genus, so the
    # reviewer's job is to look up what it actually means rather than
    # to correct a misreading.
    NAME_FIELD = "ID"

    # Also its own section, for the same reason: it is corrected through
    # a location autocompleter, which needs a real label to work.
    LOCATION_FIELD = "Location"

    # "Other Codes" is free text, but in practice a purely numeric one
    # is an iNaturalist observation id -- that is what collectors write
    # in that box. Numeric values therefore default to being stored as
    # an iNat link, the same shape the field slip form writes, with the
    # reviewer able to untick it.
    OTHER_CODES_FIELD = "Other Codes"
    INAT_CODE_RE = /\A\d+\z/

    def self.inat_code?(value)
      value.to_s.strip.match?(INAT_CODE_RE)
    end

    CONFIDENCE_LEVELS = %w[high medium low].freeze

    # A model answering JSON may stringify its booleans, and `"false"`
    # has to mean false: read as unknown it would restore the very
    # behavior the slip_present flag exists to stop. Anything absent
    # from this table -- missing, "maybe", 1 -- normalizes to nil,
    # which means unreported rather than "no slip".
    SLIP_PRESENT_VALUES = { true => true, false => false,
                            "true" => true, "false" => false }.freeze

    # What one provider run produced: the raw response (stored verbatim
    # for provenance), the per-field values, the per-field confidence
    # the model reported, and whether it saw a slip at all.
    Result = Data.define(:provider, :model, :raw, :fields, :confidence,
                         :slip_present, :unreadable) do
      def initialize(slip_present: nil, unreadable: nil, **)
        super(slip_present: SLIP_PRESENT_VALUES[normalize_flag(slip_present)],
              unreadable: known_fields(unreadable), **)
      end

      def normalize_flag(value)
        value.is_a?(String) ? value.strip.downcase : value
      end

      # Names the model invented, or a bare string where a list was
      # asked for, must not travel any further than this.
      def known_fields(value)
        Array(value).map(&:to_s) & FIELDS.keys
      end

      def value_for(slip_field) = fields[slip_field]

      def confidence_for(slip_field)
        level = confidence[slip_field].to_s.downcase
        CONFIDENCE_LEVELS.include?(level) ? level : "low"
      end

      # Nil for a read from a provider (or a prompt version) that never
      # reported it -- only an explicit false means "no slip here".
      def no_slip? = slip_present == false

      # Written on the slip but not recovered from this image, so
      # another photo of the same slip may still have it. Distinct
      # from a null whose box the collector left empty, which no
      # further photo will fill.
      def unreadable?(slip_field) = unreadable.include?(slip_field)
    end

    def self.for(provider)
      name = PROVIDERS[provider.to_sym] ||
             raise(ArgumentError.new("Unknown extractor: #{provider}"))
      name.constantize.new
    end

    def self.default = self.for(:gemini)
  end
end
