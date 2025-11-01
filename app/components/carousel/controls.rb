# frozen_string_literal: true

# Carousel navigation controls component.
#
# Renders previous/next navigation buttons for Bootstrap carousels.
#
# @example
#   render Components::Carousel::Controls.new(carousel_id: "my_carousel")
class Components::Carousel::Controls < Components::Base
  include Phlex::Rails::Helpers::LinkTo

  prop :carousel_id, String

  def view_template
    render_control(:prev)
    render_control(:next)
  end

  private

  def render_control(direction)
    position = direction == :prev ? "left" : "right"
    icon = direction == :prev ? "chevron-left" : "chevron-right"
    label = direction == :prev ? :PREV : :NEXT

    link_to("##{@carousel_id}",
            class: "#{position} carousel-control",
            role: "button",
            data: { slide: direction.to_s }) do
      div(class: "btn") do
        span(class: "glyphicon glyphicon-#{icon}", aria: { hidden: "true" })
        span(class: "sr-only") { label.l }
      end
    end
  end
end
