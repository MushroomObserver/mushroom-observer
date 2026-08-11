# frozen_string_literal: true

class FieldSlip
  module Template
    # Interface for one slip layout. Subclasses define the field table
    # and the layout-specific reading rules; everything shared between
    # layouts (transcription discipline, alias tables, output format)
    # lives in Extractor::Prompt.
    class Base
      def key = self.class.name.demodulize.underscore

      # The slip's fields, in the order they appear on the printed
      # form, mapped to where each one lands on the Observation. nil
      # means the value is reviewed but not saved directly: a
      # cross-check, or a component of another field.
      def fields = raise(NotImplementedError)

      # The field whose value becomes a proposed naming rather than an
      # attribute. Edited through a name autocompleter: collectors
      # often write a common name or a bare genus, so the reviewer's
      # job is to look up what it means, not to correct a misreading.
      def name_field = raise(NotImplementedError)

      # The field corrected through a location autocompleter, which
      # needs a real label to work.
      def location_field = raise(NotImplementedError)

      # The field whose value may hold an iNaturalist observation id,
      # stored as an iNat link when it does (see #inat_code_in).
      def inat_codes_field = raise(NotImplementedError)

      # The printed code, present on every layout. Reviewed as a
      # cross-check against the slip attached to the observation.
      def code_field = "Field Slip Code"

      # A one-sentence description of the printed layout, used to
      # decide whether the photographed slip is this template at all.
      def layout = raise(NotImplementedError)

      # Layout-specific reading rules, appended to the shared rules in
      # Extractor::Prompt.
      def field_rules = raise(NotImplementedError)

      # Collectors write iNat observation ids with separators
      # ("388 596 423", "388-401-241") or beside a username or
      # timestamp ("fungus_junkie iNat: 388891116", "10:29 388879492";
      # all real entries from the 2026 CMS fair). Digits joined across
      # single spaces/dashes make the id; seven digits minimum keeps
      # clock times, dates, and short accession numbers out.
      RAW_ID = /(?<!\d)\d(?:[\s\-–]?\d){6,9}(?!\d)/

      # The iNaturalist observation id in a value read from
      # `inat_codes_field`, or nil when the value doesn't hold one.
      def inat_code_in(value)
        inat_code_raw(value)&.gsub(/\D/, "")
      end

      # The span of the value the id was read from, as written, for
      # callers separating it from the rest of the entry.
      def inat_code_raw(value)
        value.to_s[RAW_ID]
      end

      def inat_code?(value) = inat_code_in(value).present?
    end
  end
end
