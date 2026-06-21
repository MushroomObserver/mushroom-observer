# frozen_string_literal: true

module Views::Controllers::Locations
  class Show
    # Coordinates panel — N/S/E/W bounds + high/low elevation, plus the
    # admin-only reverse / destroy actions in the heading.
    class Coordinates < Views::Base
      prop :location, ::Location

      def view_template
        render(
          ::Components::Panel.new(panel_id: "location_coordinates")
        ) do |panel|
          panel.with_heading { :COORDINATES.l }
          links = heading_links
          panel.with_heading_links { trusted_html(links) } if links.present?
          panel.with_body { render_body }
          panel.with_footer { render_footer }
        end
      end

      private

      def heading_links
        @heading_links ||= begin
                             parts = []
                             if destroyable?
                               parts << capture do
                                 render_destroy_button
                               end
                             end
                             if in_admin_mode?
                               parts << capture do
                                 render_reverse_link
                               end
                             end
                             parts.compact.safe_join(" | ")
                           end
      end

      def destroyable?
        @location.destroyable? &&
          (in_admin_mode? || @location.user == current_user)
      end

      def render_destroy_button
        render(::Components::Button::Delete.new(
                 target: @location, variant: :strip
               ))
      end

      def render_reverse_link
        title, path, opts = ::Tab::Location::ReverseOrder.new(
          location: @location
        ).to_a
        render(::Components::Link::Icon.new(title, add_q_param(path), **opts))
      end

      def render_body
        div(class: "text-center mx-auto", style: "max-width:30em") do
          render_north
          render_east_west
          render_south
          hr(class: "my-4")
          render_elevation
        end
      end

      def render_north
        div(class: "text-center my-4") do
          b { "#{:NORTH.l}:" }
          plain(" ")
          plain("#{@location.north}°")
        end
      end

      def render_south
        div(class: "text-center my-4") do
          b { "#{:SOUTH.l}:" }
          plain(" ")
          plain("#{@location.south}°")
        end
      end

      def render_east_west
        div(class: "row") do
          div(class: "col-xs-6") do
            span(class: "pull-left") do
              b { "#{:WEST.l}:" }
              plain(" ")
              plain("#{@location.west}°")
            end
          end
          div(class: "col-xs-6") do
            span(class: "pull-right") do
              b { "#{:EAST.l}:" }
              plain(" ")
              plain("#{@location.east}°")
            end
          end
        end
      end

      def render_elevation
        div(class: "text-center my-4") do
          render_elevation_line(:high, :show_location_highest)
          render_elevation_line(:low, :show_location_lowest)
        end
      end

      def render_elevation_line(attr, label_key)
        value = @location.send(attr)
        return unless value

        b(class: "text-nowrap") { "#{label_key.l}:" }
        plain(" #{value} #{:units_meters.l}")
        br
      end

      def render_footer
        render(::Components::Link::Icon.new(
                 tab: ::Tab::Location::ObservationsAt.new(location: @location),
                 show_text: true
               ))
      end
    end
  end
end
