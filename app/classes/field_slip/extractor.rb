# frozen_string_literal: true

class FieldSlip
  # Machine-reads a field slip photo into MO's own field set.
  #
  # `Extractor.for(:gemini)` returns a provider adapter; every adapter
  # answers `#extract(image, context:)` with an `Extractor::Result`, so
  # swapping providers -- or A/B-ing a new one against Gemini -- touches
  # nothing but this registry. Providers do the HTTP call and hand back
  # whatever JSON they produced; turning that into MO fields is
  # `Extractor::Normalizer`'s job, so a new provider never reimplements
  # the mapping.
  module Extractor
    PROVIDERS = { gemini: "FieldSlip::Extractor::Gemini" }.freeze

    # Bump when the prompt changes in a way that could change results.
    # Stored on the extract so a stale read is identifiable later.
    PROMPT_VERSION = "1"

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

    CONFIDENCE_LEVELS = %w[high medium low].freeze

    # What one provider run produced: the raw response (stored verbatim
    # for provenance), the per-field values, and the per-field
    # confidence the model reported.
    Result = Data.define(:provider, :model, :raw, :fields, :confidence) do
      def value_for(slip_field) = fields[slip_field]

      def confidence_for(slip_field)
        level = confidence[slip_field].to_s.downcase
        CONFIDENCE_LEVELS.include?(level) ? level : "low"
      end
    end

    def self.for(provider)
      name = PROVIDERS[provider.to_sym] ||
             raise(ArgumentError.new("Unknown extractor: #{provider}"))
      name.constantize.new
    end

    def self.default = self.for(:gemini)
  end
end
