# frozen_string_literal: true

# "Descriptions" panel on the Location show page. Renders the
# `Views::Controllers::Descriptions::List` inside a
# `Components::Panel`; the panel heading carries a "create new
# description" icon-link.
module Views::Controllers::Locations
  class Show
    class AltDescriptionsPanel < Views::Base
      prop :user, _Nilable(::User), default: nil
      prop :object, ::Location
      # Forwarded to `Descriptions::List#current` (typed there as
      # `_Nilable(::Description)`). The currently-shown description
      # of the parent Location, used to suppress its self-link in
      # the alts list.
      prop :current, _Nilable(::Description), default: nil

      def view_template
        Panel(panel_id: "alt_descriptions") do |panel|
          panel.with_heading { :show_name_descriptions.l }
          panel.with_heading_links { heading_links }
          panel.with_body { render_body }
        end
      end

      private

      def heading_links
        Link(type: :get,
             tab: Tab::Description::Create.new(parent: @object))
      end

      def render_body
        render(Views::Controllers::Descriptions::List.new(
                 user: @user, object: @object, type: @object.type_tag,
                 current: @current,
                 empty_text: show_no_descriptions_as_string(@object.type_tag)
               ))
      end
    end
  end
end
