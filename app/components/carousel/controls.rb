# frozen_string_literal: true

# Carousel navigation controls component.
#
# Renders previous/next navigation buttons matching Bootstrap 4's
# markup (https://getbootstrap.com/docs/4.6/components/carousel/#with-indicators):
# a plain `<button type="button">` (not an `<a role="button">`)
# carrying `data-target`/`data-slide`, with the icon followed by an
# `sr-only` label span (`Components::Button`'s `variant: :strip` +
# `icon:` shape).
#
# @example
#   render Components::Carousel::Controls.new(carousel_id: "my_carousel")
class Components::Carousel::Controls < Components::Base
  prop :carousel_id, String

  def view_template
    render_control(:prev)
    render_control(:next)
  end

  private

  def render_control(direction)
    icon_type = direction == :prev ? :chevron_left : :chevron_right
    label = direction == :prev ? :prev : :next

    Button(variant: :strip,
           icon: icon_type,
           name: label.l,
           class: "carousel-control-#{direction}",
           data: { target: "##{@carousel_id}", slide: direction.to_s })
  end
end
