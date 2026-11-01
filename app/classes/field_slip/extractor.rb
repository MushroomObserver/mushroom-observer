# frozen_string_literal: true

class FieldSlip
  # Machine-reads a field slip photo into MO's own field set.
  #
  # `Extractor.for(:gemini)` returns a provider adapter; every adapter
  # answers `#extract(image, context:)` with an `Extractor::Result`, so
  # swapping providers -- or A/B-ing a new one against Gemini -- touches
  # nothing but this registry. An adapter owns its own request and
  # response parsing, and is asked -- through the shared `Prompt` -- for
  # values keyed by the labels of the slip's `Template` (which layout a
  # given photo uses comes from the project, via `Context`). Where each
  # label lands on the Observation is the Template's business and
  # `Applier`'s, so a new provider never restates the mapping.
  module Extractor
    PROVIDERS = { gemini: "FieldSlip::Extractor::Gemini" }.freeze

    # Bump when the prompt changes in a way that could change results.
    # Stored on the extract so a stale read is identifiable later --
    # which only works if this actually moves, so treat editing
    # `Prompt` (or a Template's rules) and bumping this as one act.
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
    #   4  the voucher number is identified by where it sits -- the
    #      upper-right region, around the logo rather than beside it --
    #      instead of by being printed, so a handwritten one is read
    #      too (extracts at v3 or earlier hold no voucher number for
    #      any slip filled in after the printed stickers ran out)
    #   5  the field list and reading rules come from the slip's
    #      Template rather than being MO's slip always, and the
    #      response reports template_matched, so a slip printed on a
    #      layout the project doesn't use is rejected rather than its
    #      boxes being force-fit onto the wrong field set
    PROMPT_VERSION = "5"

    CONFIDENCE_LEVELS = %w[high medium low].freeze

    # A model answering JSON may stringify its booleans, and `"false"`
    # has to mean false: read as unknown it would restore the very
    # behavior the slip_present flag exists to stop. Anything absent
    # from this table -- missing, "maybe", 1 -- normalizes to nil,
    # which means unreported rather than "no slip".
    FLAG_VALUES = { true => true, false => false,
                    "true" => true, "false" => false }.freeze

    # What one provider run produced: the raw response (stored verbatim
    # for provenance), the per-field values, the per-field confidence
    # the model reported, which template the slip was read as, whether
    # the model saw a slip at all, and whether the slip it saw was
    # printed on that template's layout.
    Result = Data.define(:provider, :model, :raw, :fields, :confidence,
                         :template, :slip_present, :template_matched,
                         :unreadable) do
      def initialize(template:, slip_present: nil, template_matched: nil,
                     unreadable: nil, **)
        super(template: template.to_s,
              slip_present: FLAG_VALUES[normalize_flag(slip_present)],
              template_matched: FLAG_VALUES[normalize_flag(template_matched)],
              unreadable: known_fields(unreadable, template), **)
      end

      def normalize_flag(value)
        value.is_a?(String) ? value.strip.downcase : value
      end

      # Names the model invented, or a bare string where a list was
      # asked for, must not travel any further than this.
      def known_fields(value, template)
        Array(value).map(&:to_s) & Template.for(template).fields.keys
      end

      def value_for(slip_field) = fields[slip_field]

      def confidence_for(slip_field)
        level = confidence[slip_field].to_s.downcase
        CONFIDENCE_LEVELS.include?(level) ? level : "low"
      end

      # Nil for a read from a provider (or a prompt version) that never
      # reported it -- only an explicit false means "no slip here".
      def no_slip? = slip_present == false

      # A slip was seen, but printed on a different layout than this
      # project's slips use, so nothing was read off it.
      def template_mismatch? = !no_slip? && template_matched == false

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
