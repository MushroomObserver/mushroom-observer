# frozen_string_literal: true

# "Matching Observations" panel. Lists every occurrence member as a
# 3-column flex row: the marker (a chevron for the observation being
# viewed, a footnote number or nothing for a sibling), the name (a
# status icon, then the name -- plain text for the current
# observation, a link for a sibling), then a Badge(variant: :id). The
# name column is the only one that grows/wraps, keeping the marker
# and id badge in their columns regardless of name length. No
# occurrence yet: just an "Add Matching Observations" link, no body.
#
class Views::Controllers::Observations::Show::MatchingObservationsPanel < Views::Base
  include Views::Controllers::Observations::Show::OccurrenceStatusIcons

  prop :obs, ::Observation
  prop :occurrence, _Nilable(::Occurrence), default: nil
  prop :siblings, _Array(::Observation), default: -> { [] }
  # {observation id => footnote number}. This panel is where a
  # reader looks up what a number on a comment or photo means,
  # so it has to show the same ones (#5718).
  prop :markers, _Hash(::Integer, ::Integer), default: -> { {} }

  def view_template
    Panel(id: "matching_observations") do |panel|
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
         show_label: :always)
  end

  # position-relative anchors each row's tooltip (see
  # render_status_icons) instead of it drifting elsewhere on the page.
  def render_body
    ul(class: "tight-list pl-0 mb-0") do
      li(class: "current-observation-row position-relative") do
        render_member_row(@obs, link: false)
      end
      @siblings.each do |sibling|
        li(class: "position-relative") do
          render_member_row(sibling, link: true)
        end
      end
    end
  end

  # Icons sit inside the <a> when the row is a link, so hovering or
  # clicking an icon also hovers/clicks the link.
  def render_member_row(member, link:)
    div(class: "matching-observation-row mb-1") do
      render_marker(member, current: !link)
      render_member_name_cell(member, link: link)
      Badge(variant: :id, object: member, size: :lg, interactive: link,
            extra_class: "mb-0")
    end
  end

  def render_member_name_cell(member, link:)
    icon_types = member_status_icon_types(member, @occurrence)
    gap_class = "icon-text-gap" if icon_types.any?
    div(class: "matching-observation-name") do
      if link
        render_member_link(member, icon_types, gap_class)
      else
        render_status_icons(icon_types)
        render_current_observation_name(member, gap_class)
      end
    end
  end

  def render_member_link(member, icon_types, gap_class)
    Link(type: :get, name: member.format_name(default_viewer).t,
         target: permanent_observation_path(member.id)) do
      render_status_icons(icon_types)
      span(class: gap_class) do
        trusted_html(member.format_name(default_viewer).t)
      end
    end
  end

  # The chevron marks which row is the observation being viewed; its
  # aria-label carries the same information to a screen reader, since
  # the icon alone has no accessible name. A sibling's marker (or
  # lack of one) comes from @markers -- every marker on the page goes
  # to its member, this one too, so a number behaves the same
  # wherever it is read. Either way the column always renders (even
  # empty), so every row's name and id badge start at the same place.
  # aria-label: the chevron has no accessible name.
  def render_marker(member, current:)
    div(class: "matching-observation-marker") do
      if current
        Icon(type: :chevron_right,
             aria: { label: :show_observation_this_observation.t })
      else
        marker = @markers[member.id]
        if marker
          Badge(variant: :sibling_marker, number: marker,
                observation_id: member.id)
        end
      end
    end
  end

  # format_name, not unique_format_name -- the badge already shows the id.
  def render_current_observation_name(member, gap_class)
    span(class: gap_class) do
      trusted_html(member.format_name(default_viewer).t)
    end
  end

  # Icon logic lives in the shared OccurrenceStatusIcons concern.
end
