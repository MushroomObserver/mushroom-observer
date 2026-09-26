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
  # Rendered `d-none` when there's nothing to navigate to yet (e.g.
  # the upload form's carousel starts empty) -- `form-images_
  # controller.js#showOrHideCarouselControls` toggles it from there
  # as items are added/removed. Kept in the DOM either way so that
  # JS has an element to reveal.
  prop :hidden, _Boolean, default: false

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
           class: class_names("carousel-control-#{direction}",
                              ("d-none" if @hidden)),
           data: { target: "##{@carousel_id}", slide: direction.to_s })
  end
end
