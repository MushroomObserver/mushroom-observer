# frozen_string_literal: true

class FieldSlip
  module Template
    # Mushroom Observer's own printed slip.
    class Mo < Base
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

      def fields = FIELDS
      def name_field = "ID"
      def location_field = "Location"
      def inat_codes_field = "Other Codes"

      def layout
        "Mushroom Observer's printed form: a QR code and printed " \
          "field slip code at the top, then boxes labeled Collector, " \
          "Date, Location, Notes, Odor/Taste, Trees/Shrubs, " \
          "Substrate, Habit, ID, ID By, and Other Codes, with a " \
          "MycoMap voucher sticker area in the upper-right region."
      end

      def field_rules
        <<~RULES.strip
          - "ID" is the name written by the collector. It may be a
            scientific name, a common name, or a genus alone. Give it
            verbatim.
          - Substrate and Habit are often circled from a printed list
            rather than written. Report the circled word(s).
          - "MycoMap Voucher Number" sits in the slip's upper-right
            region, printed or handwritten. It is usually a printed
            sticker like N26-0290; when the stickers ran out it was
            written in by hand, often as a bare number with the prefix
            left off. A logo usually occupies that corner, and a
            handwritten number may be above it or to its left rather
            than beside it, so read the whole upper-right area. Give
            it exactly as written -- do not add a prefix a bare number
            does not carry. It is not the field slip code. Identify it
            by that region, not by whether it is printed: anything
            written in another box belongs to that box's field, and
            "Other Codes" is only what a person wrote in the Other
            Codes box.
        RULES
      end
    end
  end
end
