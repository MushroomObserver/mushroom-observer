# frozen_string_literal: true

module Views::Controllers::Locations
  class Show
    # General-description panel — show + edit icon links on the heading,
    # textile-rendered description body. Only renders when the location
    # has an attached description with notes.
    class GeneralDescriptionPanel < Views::Base
      prop :location, ::Location
      prop :description, _Nilable(::LocationDescription), default: nil

      def view_template
        return unless @description&.notes?

        Panel(panel_id: "location_general_description") do |panel|
          panel.with_heading { :show_name_general_description.l }
          links = heading_links_text
          if current_user && links
            panel.with_heading_links { trusted_html(links) }
          end
          panel.with_body { trusted_html(@description.notes.tpl) }
        end
      end

      private

      def heading_links_text
        return unless current_user

        parts = [
          render_to_string_link(::Tab::Location::ShowDescription),
          render_to_string_link(::Tab::Location::EditDescription)
        ].compact
        return if parts.empty?

        parts.safe_join(" | ")
      end

      def render_to_string_link(tab_class)
        capture do
          Link(type: :icon, tab: tab_class.new(location: @location))
        end
      end
    end
  end
end
