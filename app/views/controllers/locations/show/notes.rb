# frozen_string_literal: true

module Views::Controllers::Locations
  class Show
    # Notes panel — only renders when the location has notes.
    class Notes < Views::Base
      prop :location, ::Location

      def view_template
        return if @location.notes.blank?

        Panel(panel_id: "location_notes") do |panel|
          panel.with_heading { :notes.ti }
          panel.with_body { trusted_html(@location.notes.to_s.tpl) }
        end
      end
    end
  end
end
