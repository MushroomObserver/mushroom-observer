# frozen_string_literal: true

# The footnote number saying which occurrence member a comment or
# photo came from (#5718). The observation being viewed carries no
# number; siblings are numbered from 1 in observation-id order, and
# the Matching Observations panel shows the same numbers, where they
# read as the legend for the rest of the page.
#
# Shaped like the checklist page's count badge, which is the
# established bubble on MO.
#
# @example
#   Badge(variant: :sibling_marker, number: 2, observation_id: 663635)
class Components::Badge::SiblingMarker < Components::Badge
  prop :number, ::Integer
  prop :observation_id, _Nilable(::Integer), default: nil
  # Linked wherever the id is known -- see the Matching Observations
  # panel's `render_marker` for why its row links the number too.
  prop :link, _Boolean, default: true
  # An outlined badge vanishes into a photograph, so the one laid over
  # a carousel thumbnail fills instead of outlining.
  prop :fill, _Union(:outline, :solid), default: :outline
  # Inside a Bootstrap carousel indicator, a click that reaches the
  # carousel's handler is cancelled, so the link needs to keep the
  # click to itself. See links_controller.js#follow.
  prop :isolate_click, _Boolean, default: false
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template
    linked? ? render_link : render_badge
  end

  private

  def linked?
    @link && @observation_id
  end

  def render_link
    a(**link_attributes) { render_badge }
  end

  def link_attributes
    attrs = { href: permanent_observation_path(@observation_id),
              class: "sibling-marker-link" }
    return attrs unless @isolate_click

    attrs.merge(data: { controller: "links",
                        action: "click->links#follow:stop" })
  end

  def render_badge
    span(**mix(badge_attributes, @attributes)) { @number.to_s }
  end

  def badge_attributes
    attrs = { class: "badge sibling-marker #{fill_class}" }
    attrs[:data] = { tooltip_target: "tip", title: title_text } if
      @observation_id
    attrs
  end

  def fill_class
    @fill == :solid ? "sibling-marker-solid" : "badge-outline"
  end

  def title_text
    :show_observation_sibling_marker.l(id: @observation_id)
  end
end
