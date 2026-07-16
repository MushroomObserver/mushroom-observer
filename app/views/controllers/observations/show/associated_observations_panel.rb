# frozen_string_literal: true

# "Matching observations" panel on the observation show page. When
# the observation's occurrence has siblings, the heading is the bare
# "Occurrences" title with an icon-only link to the occurrence
# flush right, and the body lists the sibling observations as a
# tight ul. When there's no occurrence yet, the whole heading is an
# icon+text "Add Matching Observations" link (no body).
#
class Views::Controllers::Observations::Show::AssociatedObservationsPanel < Views::Base
  prop :obs, ::Observation
  prop :occurrence, _Nilable(::Occurrence), default: nil
  prop :siblings, _Array(::Observation), default: -> { [] }

  def view_template
    Panel(panel_id: "associated_observations") do |panel|
      if siblings?
        panel.with_heading { plain(:OCCURRENCES.t) }
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
    Link(type: :icon,
         tab: ::Tab::Observation::MatchingObservations.new(
           occurrence: @occurrence
         ))
  end

  def add_matching_observations_link
    Link(type: :icon,
         tab: ::Tab::Observation::AddMatchingObservations.new(obs: @obs),
         show_text: true)
  end

  def render_body
    ul(class: "tight-list") do
      @siblings.each do |sibling|
        li do
          a(href: permanent_observation_path(sibling.id)) do
            trusted_html(viewer_aware_unique_format_name(sibling).t)
          end
        end
      end
    end
  end
end
