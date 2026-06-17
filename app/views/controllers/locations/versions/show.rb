# frozen_string_literal: true

module Views::Controllers::Locations
  module Versions
    # Past-version page for a location — the map (read-only), the
    # coordinates and notes panels for THIS version of the location,
    # the versions table, and the version footer.
    class Show < Views::Base
      prop :location, ::Location
      prop :versions, _Array(_Interface(:user_id))

      def view_template
        register_chrome
        div(class: "row") { render_columns }
        render(Views::Controllers::Versions::Table.new(
                 obj: @location, versions: @versions.to_a
               ))
        render(::Views::Layouts::ObjectFooter.new(
                 user: current_user, obj: @location, versions: @versions.to_a
               ))
      end

      private

      def register_chrome
        add_page_title(:show_past_location_title.t(
                         num: @location.version, name: @location.display_name
                       ))
        add_context_nav(
          ::Tab::Location::VersionActions.new(location: @location)
        )
        column_classes(:seven_five)
      end

      def render_columns
        div(class: content_for(:left_columns)) do
          div(class: "mb-5") do
            render(::Components::Map.new(objects: [@location]))
          end
        end
        div(class: content_for(:right_columns)) do
          render(Views::Controllers::Locations::Show::Coordinates.new(
                   location: @location
                 ))
          render(Views::Controllers::Locations::Show::Notes.new(
                   location: @location
                 ))
        end
      end
    end
  end
end
