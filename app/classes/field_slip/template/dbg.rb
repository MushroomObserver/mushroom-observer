# frozen_string_literal: true

class FieldSlip
  module Template
    # Andy Wilson's voucher slip (Denver Botanic Gardens), used by the
    # 2025 NAMA foray and the 2026 CMS fair / SMHF collections. The
    # logo and the options printed in the Plants list vary per event;
    # the layout is shared.
    class Dbg < Base
      FIELDS = {
        "Field Slip Code" => nil,
        "Voucher Number" => :"notes.Voucher_Number",
        "Date" => :when,
        "Collector" => :collector,
        # State and County are components of the location; the
        # reviewed place name carries them, so they are not stored
        # separately.
        "State" => nil,
        "County" => nil,
        "Location/Foray" => :place_name,
        "Latitude" => :lat,
        "Longitude" => :lng,
        "Species" => nil,
        "ID By" => :"notes.Field_Slip_ID_By",
        "ID Date" => :"notes.Field_Slip_ID_Date",
        "Notes" => :"notes.Other",
        "Odor/Taste" => :"notes.Odor/Taste",
        "Plants" => :"notes.Plants",
        "Substrate" => :"notes.Substrate",
        "Habit" => :"notes.Habit",
        "iNaturalist" => :"notes.iNaturalist"
      }.freeze

      def fields = FIELDS
      def name_field = "Species"
      def location_field = "Location/Foray"
      def inat_codes_field = "iNaturalist"

      def layout
        "a voucher slip with a ruler printed along its top edge and a " \
          "header row holding a QR code, a large printed code (like " \
          "2026-CMS-0219), and an event or herbarium logo. The left " \
          "column has boxes labeled Date, Collector, State, County, " \
          "Location/Foray, Latitude, Longitude, and Species, with ID " \
          "by and ID date at the bottom. The right column has Notes, " \
          "Odor/taste, a printed Plants list, a Substrate/Habit " \
          "checklist, and an iNaturalist box, with the printed code " \
          "repeated in the lower right."
      end

      def field_rules
        <<~RULES.strip
          - "Species" is the name written by the collector. It may be
            a scientific name, a common name, or a genus alone. Give
            it verbatim.
          - "State" is usually a two-letter abbreviation. Give it as
            written.
          - "Plants" is a printed list of trees and shrubs; the
            collector circles what applies. Report the circled
            word(s), separated by commas.
          - "Substrate" and "Habit" share one printed checklist headed
            Substrate/Habit. The Substrate options (soil, wood,
            litter) have a blank line beneath them for write-ins; the
            Habit options are Solitary, Gregarious, and Caespitose.
            Report checked, circled, or underlined words under their
            own key, and anything handwritten on the blank line as
            Substrate.
          - "iNaturalist" is the box labeled iNaturalist. Collectors
            write an observation number, a username, a timestamp, or a
            combination. Transcribe the whole entry exactly as
            written.
          - "Voucher Number" is a specimen sticker in the slip's
            upper-right region, on or near the logo, like CO26-0290.
            Most slips have none. It may be handwritten. It is not the
            field slip code. Give it exactly as written.
        RULES
      end

      # The box is dedicated to iNaturalist, so the digits in it are
      # the observation id -- and collectors write them with separators
      # ("388 596 423", "388-401-241") or beside a username or
      # timestamp ("fungus_junkie iNat: 388891116", "10:29 388879492";
      # all real entries from the 2026 CMS fair). Digits joined across
      # single spaces/dashes make the id; seven digits minimum keeps
      # clock times and dates out.
      RAW_ID = /(?<!\d)\d(?:[\s\-–]?\d){6,9}(?!\d)/

      def inat_code_in(value)
        inat_code_raw(value)&.gsub(/\D/, "")
      end

      # The id as actually written, for callers separating it from the
      # rest of the entry.
      def inat_code_raw(value)
        value.to_s[RAW_ID]
      end
    end
  end
end
