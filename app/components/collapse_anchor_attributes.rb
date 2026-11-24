# frozen_string_literal: true

# Shared `href`/`data`/`aria` resolution for anchor-based collapse
# triggers. Included by both `Components::Link::CollapseToggle` and
# `Components::Badge::CollapseToggle`. Requires `@target_id`,
# `@fallback_href`, `@collapsed`, and `@attributes` on the including
# class.
module Components::CollapseAnchorAttributes
  private

  def link_href
    @fallback_href || "##{@target_id}"
  end

  # `expanded:`/`controls:` are derived from `@collapsed`/`@target_id`
  # and always win -- a caller passes other aria attrs (`label:`,
  # `describedby:`, etc.) through `aria:`, not a recomputation of
  # these two that could drift from the toggle's state.
  def collapse_aria
    extra_aria = (@attributes[:aria] || {}).except(:expanded, :controls)
    { expanded: @collapsed ? "false" : "true",
      **(@target_id.present? ? { controls: @target_id } : {}),
      **extra_aria }
  end

  def collapse_data
    extra_data = @attributes[:data] || {}
    return extra_data unless @fallback_href

    # Bootstrap 4's collapse data-API calls preventDefault()
    # unconditionally, so a fallback_href anchor's navigation is
    # already blocked with no JS workaround needed -- data-target
    # just has to be present so collapse.js can find the pane.
    extra_data.merge(target: "##{@target_id}")
  end
end
