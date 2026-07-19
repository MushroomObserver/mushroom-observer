# frozen_string_literal: true

module Views::Controllers::Locations
  class Show
    # Footer panel — authors / editors + previous-version link.
    class Footer < Views::Base
      prop :location, ::Location
      prop :versions, _Array(_Interface(:user_id))

      def view_template
        Panel(panel_id: "location_footer") do |panel|
          panel.with_body { render_body }
          panel.with_footer { render_previous_version }
        end
      end

      private

      def render_body
        div(id: "location_authors_editors") do
          render(::Views::Layouts::AuthorsAndEditors.new(
                   obj: @location, versions: @versions.to_a, user: current_user
                 ))
        end
        trusted_html(
          :show_name_num_notifications.t(num: @location.interests)
        )
      end

      def render_previous_version
        div(id: "location_previous") do
          render(::Components::Description::PreviousVersion.new(
                   obj: @location, versions: @versions.to_a
                 ))
        end
      end
    end
  end
end
