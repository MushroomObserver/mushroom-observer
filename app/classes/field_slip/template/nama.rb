# frozen_string_literal: true

class FieldSlip
  module Template
    # The NAMA 2026 foray slip: a DBG-derived layout that drops the
    # Voucher Number / State / County boxes, widens the iNaturalist box
    # to "iNaturalist/MO", replaces the printed Plants list with blank
    # Conifer / Deciduous / Other Host lines, and adds faint DNA and
    # VCP labels in the header's corners.
    class Nama < Base
      FIELDS = {
        "Field Slip Code" => nil,
        # DNA and VCP are sticker slots: the faint corner labels mark
        # where DNA-sequencing and Voucher Collection Program stickers
        # go. The sticker design isn't settled yet, so the rule below
        # stays agnostic about what one looks like.
        "DNA" => :"notes.DNA",
        "VCP" => :"notes.VCP",
        "Date" => :when,
        "Collector" => :collector,
        "Location/Foray" => :place_name,
        "Latitude" => :lat,
        "Longitude" => :lng,
        "Notes" => :"notes.Other",
        "Odor/Taste" => :"notes.Odor/Taste",
        "Trees/Plants" => :"notes.Plants",
        "Substrate" => :"notes.Substrate",
        "Habit" => :"notes.Habit",
        "Species" => nil,
        "iNaturalist/MO" => :"notes.iNaturalist",
        "ID By" => :"notes.Field_Slip_ID_By",
        "ID Date" => :"notes.Field_Slip_ID_Date"
      }.freeze

      def fields = FIELDS
      def name_field = "Species"
      def location_field = "Location/Foray"

      # An MO observation id written here cannot be mistaken for an
      # iNat one: MO ids are 6 digits, below RAW_ID's 7-digit floor.
      def inat_codes_field = "iNaturalist/MO"

      def layout
        "a voucher slip with a ruler printed along its top edge and a " \
          "header row holding a QR code, a large printed code (like " \
          "2026-NAMA-0001), and the North American Mycological " \
          "Association logo, with faint DNA and VCP labels in the " \
          "upper corners. Below the header are boxes labeled Date and " \
          "Collector, then Location/Foray beside Latitude and " \
          "Longitude. The middle band has Notes and Odor/taste on the " \
          "left, a Trees/Plants section with blank lines headed " \
          "Conifer, Deciduous, and Other Host, and a Substrate/Habit " \
          "checklist with a Substrate Detail line. Below are Species " \
          "and an iNaturalist/MO box, with ID by and ID date at the " \
          "bottom and the printed code repeated in the lower right."
      end

      def field_rules
        <<~RULES.strip
          - "Species" is the name written by the collector. It may be
            a scientific name, a common name, or a genus alone. Give
            it verbatim.
          - "DNA" and "VCP" are printed faintly in the header's upper
            corners, marking where a DNA-sequencing or voucher sticker
            may be affixed. When a sticker covers one, report the
            sticker's printed or written text; if the sticker carries
            no readable text, report "present". The faint printed
            label alone, with no sticker over it, is null.
          - "Trees/Plants" is a section with blank lines headed
            Conifer, Deciduous, and Other Host; the collector writes
            tree or plant names on them. Report what is written,
            separated by commas.
          - "Substrate" and "Habit" share one printed checklist headed
            Substrate/Habit. The Substrate options (soil, wood,
            litter) are followed by a Substrate Detail line for
            write-ins; the Habit options are Solitary, Gregarious, and
            Caespitose. Report checked, circled, or underlined words
            under their own key, and anything handwritten on the
            Substrate Detail line as Substrate.
          - "iNaturalist/MO" is the box labeled iNaturalist/MO.
            Collectors write an iNaturalist or Mushroom Observer
            observation number, a username, a timestamp, or a
            combination. Transcribe the whole entry exactly as
            written.
        RULES
      end
    end
  end
end
