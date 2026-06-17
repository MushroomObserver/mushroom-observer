# frozen_string_literal: true

module Views::Controllers::Locations
  class Show
    # Footer panel — authors / editors + previous-version link.
    class Footer < Views::Base
      prop :location, ::Location
      prop :versions,
           _Union(Array, ::ActiveRecord::Associations::CollectionProxy)

      def view_template
        render(::Components::Panel.new(panel_id: "location_footer")) do |panel|
          panel.with_body { render_body }
          panel.with_footer { render_previous_version }
        end
      end

      private

      def render_body
        div(id: "location_authors_editors") do
          render(::Components::AuthorsAndEditors.new(
                   obj: @location, versions: @versions, user: current_user
                 ))
        end
        trusted_html(
          :show_name_num_notifications.t(num: @location.interests)
        )
      end

      def render_previous_version
        div(id: "location_previous") do
          render(::Components::PreviousVersion.new(
                   obj: @location, versions: @versions
                 ))
        end
      end
    end
  end
end
