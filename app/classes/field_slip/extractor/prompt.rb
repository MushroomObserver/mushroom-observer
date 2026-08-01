# frozen_string_literal: true

class FieldSlip
  module Extractor
    # Builds the extraction instructions for one image.
    #
    # The abbreviation tables come from the project's own ProjectAliases
    # rather than being written into the prompt: a foray's walk numbers
    # and member initials already live there (see #4932), they change
    # between forays, and every alias an admin adds while reviewing
    # improves the next extraction. The 2025 script hardcoded the
    # equivalent 2025 site list, which is why it could not be reused.
    class Prompt
      MAX_ALIASES = 60

      def initialize(context)
        @context = context
      end

      def to_s
        [preamble, field_rules, location_table, user_table, date_rule,
         output_format].compact.join("\n\n")
      end

      private

      def preamble
        "Extract the data written on this mushroom field slip. The slip " \
          "is a printed form; most values are handwritten. Ignore the " \
          "specimen photographed beside it -- do not identify the " \
          "mushroom yourself, only transcribe what the slip says."
      end

      def field_rules
        <<~RULES.strip
          Fields to extract, using exactly these keys:
          #{Extractor::FIELDS.keys.map { |f| "  - #{f}" }.join("\n")}

          Rules:
          - Transcribe what is written. Do not correct spelling or
            expand a name you are unsure of.
          - Use null for a field that is blank or unreadable.
          - "Field Slip Code" is printed, not handwritten, and looks
            like #{code_example}. It also appears in the QR code.
          - "ID" is the name written by the collector. It may be a
            scientific name, a common name, or a genus alone. Give it
            verbatim.
          - Substrate and Habit are often circled from a printed list
            rather than written. Report the circled word(s).
          - "MycoMap Voucher Number" is the PRINTED code in the slip's
            top-right corner, like N26-0290. It is not handwritten and
            is not the field slip code. Do not put it in "Other Codes";
            "Other Codes" is only what a person wrote in that box.
        RULES
      end

      def code_example
        @context.field_slip_code.presence || "NEMF-10222"
      end

      # Walk numbers and site abbreviations, straight from the project.
      def location_table
        rows = alias_rows("Location")
        return nil if rows.empty?

        "\"Location\" is usually a walk number or site abbreviation. " \
          "Map it to the full location name using this table, and " \
          "return the FULL NAME:\n#{rows}\n" \
          "If the written value is not in the table, return it " \
          "verbatim -- do not guess which site was meant."
      end

      # Initials for Collector / ID By. Same reasoning: return the
      # abbreviation verbatim when it is not in the table, so the
      # reviewer sees an unknown one rather than a plausible wrong name.
      # The table is a reading aid, not a substitution rule. Expanding
      # "dcs" to "Dorothy Smullen" destroys the value: the initials
      # resolve to a User two ways (this alias table, and a login
      # lookup) while the expanded display name resolves neither, so MO
      # can no longer link the note to the person. Transcribe; MO
      # expands.
      def user_table
        rows = alias_rows("User")
        return nil if rows.empty?

        "\"Collector\" and \"ID By\" are often initials. This project " \
          "uses:\n#{rows}\n" \
          "Use the table only to read the handwriting. Return what is " \
          "WRITTEN -- the initials, not the expanded name."
      end

      def alias_rows(target_type)
        @context.aliases(target_type).first(MAX_ALIASES).map do |name, full|
          "  #{name} = #{full}"
        end.join("\n")
      end

      # The foray's own dates beat a hardcoded month: a slip dated
      # outside them is far more likely misread than real.
      def date_rule
        range = @context.date_range
        return "Return \"Date\" as YYYY-MM-DD." unless range

        "Return \"Date\" as YYYY-MM-DD. This event ran " \
          "#{range.first} to #{range.last}; a date outside that range " \
          "is probably a misreading, so re-check it before answering. " \
          "Slips often write only a month and day."
      end

      def output_format
        <<~FORMAT.strip
          Return ONLY a JSON object, with no markdown fence, of the form:

          {
            "fields": { <each key above>: <string or null> },
            "confidence": { <each key above>: "high" | "medium" | "low" },
            "notes": "anything about readability worth a reviewer knowing"
          }
        FORMAT
      end
    end
  end
end
