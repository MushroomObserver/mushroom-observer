# frozen_string_literal: true

# "Matching observations" panel on the observation show page. When
# the observation's occurrence has siblings, the heading is the bare
# "Matching Observations" title with an icon-only link to the occurrence
# flush right, and the body lists every member of the occurrence
# (current observation first, as plain text, then siblings as links)
# as a tight ul. Each row leads with an `IDBadge` (non-interactive for
# the current observation, matching its non-link name; interactive
# copy-to-clipboard for siblings), then a status icon for the
# occurrence's primary and any read-only reflection, then the name
# via `format_name` (not `unique_format_name` -- the badge already
# shows the id; current observation: plain text, tagged "(this
# observation)"; siblings: a link). When there's no occurrence yet,
# the whole heading is an icon+text "Add Matching Observations" link
# (no body).
#
class Views::Controllers::Observations::Show::MatchingObservationsPanel < Views::Base
  prop :obs, ::Observation
  prop :occurrence, _Nilable(::Occurrence), default: nil
  prop :siblings, _Array(::Observation), default: -> { [] }

  def view_template
    Panel(panel_id: "matching_observations") do |panel|
      if siblings?
        panel.with_heading { plain(:show_observation_matching_observations.ti) }
        panel.with_heading_links { matching_observations_link }
        panel.with_body { render_body }
      else
        panel.with_heading { add_matching_observations_link }
      end
    end
  end

  private

  def siblings?
    @occurrence && @siblings.any?
  end

  def matching_observations_link
    Link(type: :get,
         tab: ::Tab::Observation::MatchingObservations.new(
           occurrence: @occurrence
         ))
  end

  def add_matching_observations_link
    Link(type: :get,
         tab: ::Tab::Observation::AddMatchingObservations.new(obs: @obs),
         label: true)
  end

  def render_body
    ul(class: "tight-list pl-0 mb-0") do
      li { render_member_row(@obs, link: false) }
      @siblings.each { |sibling| li { render_member_row(sibling, link: true) } }
    end
  end

  def render_member_row(member, link:)
    IDBadge(object: member, size: :lg, interactive: link, extra_class: "mr-3")
    icon_types = member_status_icon_types(member)
    render_status_icons(icon_types)
    render_member_name(member, link: link, gap: icon_types.any?)
  end

  # `format_name`, not `unique_format_name` -- the latter appends the
  # observation's id, which the IDBadge above already shows. Needs a
  # gap only when a status icon precedes it -- otherwise the badge's
  # trailing margin is already the gap.
  def render_member_name(member, link:, gap:)
    gap_class = "icon-text-gap" if gap
    if link
      a(class: gap_class, href: permanent_observation_path(member.id)) do
        trusted_html(member.format_name(default_viewer).t)
      end
    else
      span(class: gap_class) do
        trusted_html(member.format_name(default_viewer).t)
        whitespace
        plain("(#{:show_observation_this_observation.l})")
      end
    end
  end

  # `member`'s status icon types (0, 1, or 2): occurrence primary,
  # read-only reflection. Compares against `@occurrence` directly
  # (not `member.occurrence_primary?`) to avoid an N+1 lookup per row
  # -- every member here already belongs to the same @occurrence.
  def member_status_icon_types(member)
    types = []
    types << :is_primary if @occurrence.primary_observation_id == member.id
    types << :read_only if member.reflection?
    types
  end

  # The first icon follows the badge, whose trailing margin is already
  # the gap; a second icon follows the first and needs a gap too --
  # via wrap_class:, not class:, since a padding class landing on the
  # bare <svg> shrinks it instead of adding space around it (see
  # Components::Icon).
  #
  # data-tooltip-container: "li" -- Bootstrap's tooltip.js default
  # (container: false) inserts the tooltip as the icon's tight inline
  # sibling, where this row's cramped layout mis-renders it; appending
  # it into the row's <li> instead fixes that (see the identical fix
  # for the image vote button group in tooltip_controller.js).
  def render_status_icons(types)
    types.each_with_index do |type, index|
      wrap_class = "icon-text-gap" if index.positive?
      Icon(type: type, title: status_icon_title(type), wrap_class: wrap_class,
           data: { tooltip_container: "li" })
    end
  end

  def status_icon_title(type)
    case type
    when :is_primary then :show_observation_occurrence_primary.ti
    when :read_only then :show_observation_reflection_read_only.ti
    end
  end
end
