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

        Panel(id: "location_general_description") do |panel|
          panel.with_heading { :show_name_general_description.l }
          panel.with_heading_links { render_heading_links } if current_user
          panel.with_body { trusted_html(@description.notes.tpl) }
        end
      end

      private

      def render_heading_links
        InlineIconBlock(items: [show_link, edit_link])
      end

      def show_link
        tab_link(::Tab::Location::ShowDescription)
      end

      def edit_link
        tab_link(::Tab::Location::EditDescription)
      end

      def tab_link(tab_class)
        Components::Link.new(
          type: :get, tab: tab_class.new(location: @location),
          class: Components::InlineIconBlock.item_class
        )
      end
    end
  end
end
