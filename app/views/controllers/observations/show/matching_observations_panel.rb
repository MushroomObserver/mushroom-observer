# frozen_string_literal: true

# "Matching Observations" panel. Lists every occurrence member: an
# IDBadge, a status icon (occurrence primary / read-only reflection),
# then the name -- current observation as plain text tagged "(this
# observation)"; siblings as links. No occurrence yet: just an "Add
# Matching Observations" link, no body.
#
class Views::Controllers::Observations::Show::MatchingObservationsPanel < Views::Base
  include Views::Controllers::Observations::Show::OccurrenceStatusIcons

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

  # position-relative anchors each row's tooltip (see
  # render_status_icons) instead of it drifting elsewhere on the page.
  def render_body
    ul(class: "tight-list pl-0 mb-0") do
      li(class: "position-relative") { render_member_row(@obs, link: false) }
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
    IDBadge(object: member, size: :lg, interactive: link, extra_class: "mr-3")
    icon_types = member_status_icon_types(member, @occurrence)
    gap_class = "icon-text-gap" if icon_types.any?
    if link
      a(href: permanent_observation_path(member.id)) do
        render_status_icons(icon_types)
        span(class: gap_class) do
          trusted_html(member.format_name(default_viewer).t)
        end
      end
    else
      render_status_icons(icon_types)
      render_current_observation_name(member, gap_class)
    end
  end

  # format_name, not unique_format_name -- the badge already shows the id.
  def render_current_observation_name(member, gap_class)
    span(class: gap_class) do
      trusted_html(member.format_name(default_viewer).t)
      whitespace
      plain("(#{:show_observation_this_observation.l})")
    end
  end

  # Icon logic lives in the shared OccurrenceStatusIcons concern.
end
