# frozen_string_literal: true

# Star/lock status icons for an occurrence member: occurrence-primary
# (:is_primary) and read-only reflection (:read_only). Shared by the
# Matching Observations panel and the Specimen panel's sequences
# section so the iconography stays identical.
module Views::Controllers::Observations::Show::OccurrenceStatusIcons
  private

  # Compares against the occurrence directly, not
  # member.occurrence_primary?, to avoid an N+1 lookup per row.
  def member_status_icon_types(member, occurrence)
    return [] unless occurrence

    types = []
    types << :is_primary if occurrence.primary_observation_id == member.id
    types << :read_only if member.reflection?
    types
  end

  # wrap_class:, not class: -- padding on a bare <svg> shrinks it
  # (see Components::Icon). tooltip_container: "li" keeps the tooltip
  # from mis-rendering in these rows' tight layout.
  def render_status_icons(types)
    types.each_with_index do |type, index|
      wrap_class = "icon-text-gap" if index.positive?
      Icon(type: type, title: status_icon_title(type),
           wrap_class: wrap_class, data: { tooltip_container: "li" })
    end
  end

  def status_icon_title(type)
    case type
    when :is_primary then :show_observation_occurrence_primary.l
    when :read_only then :show_observation_reflection_read_only.l
    end
  end
end
