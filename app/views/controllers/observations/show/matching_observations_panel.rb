# frozen_string_literal: true

# "Matching observations" panel on the observation show page. When
# the observation's occurrence has siblings, the heading is the bare
# "Matching Observations" title with an icon-only link to the occurrence
# flush right, and the body lists every member of the occurrence
# (current observation first, as plain text, then siblings as links)
# as a tight ul, each row carrying a status icon for the occurrence's
# primary and any read-only reflection. When there's no occurrence
# yet, the whole heading is an icon+text "Add Matching Observations"
# link (no body).
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
    icon_types = member_status_icon_types(member)
    render_status_icons(icon_types)
    gap_class = "icon-text-gap" if icon_types.any?
    if link
      a(class: gap_class, href: permanent_observation_path(member.id)) do
        trusted_html(viewer_aware_unique_format_name(member).t)
      end
    else
      span(class: gap_class) do
        trusted_html(viewer_aware_unique_format_name(member).t)
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

  # A second icon on the same row needs the same gap the trailing text
  # gets, or it renders flush against the first icon.
  def render_status_icons(types)
    types.each_with_index do |type, index|
      gap_class = "icon-text-gap" if index.positive?
      Icon(type: type, title: status_icon_title(type), class: gap_class)
    end
  end

  def status_icon_title(type)
    case type
    when :is_primary then :show_observation_occurrence_primary.t
    when :read_only then :show_observation_reflection_read_only.t
    end
  end
end
