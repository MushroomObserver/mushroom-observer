# frozen_string_literal: true

# "Matching observations" panel on the observation show page.
# Heading links to the occurrence (when one exists with siblings)
# or to "create a new occurrence from this observation" (when none
# exists yet). Body lists sibling observations as a tight ul.
#
# Replaces `_associated_observations.html.erb`.
module Views::Controllers::Observations::Show
  class AssociatedObservationsPanel < Views::Base
    prop :obs, ::Observation
    prop :occurrence, _Nilable(::Occurrence), default: nil
    prop :siblings, _Array(::Observation), default: -> { [] }
    prop :user, _Nilable(::User), default: nil

    def view_template
      render(Components::Panel.new(
               panel_id: "associated_observations",
               panel_class: "name-section"
             )) do |panel|
        panel.with_heading { render_heading_link }
        panel.with_body { render_body } if siblings?
      end
    end

    private

    def siblings?
      @occurrence && @siblings.any?
    end

    def render_heading_link
      if siblings?
        a(href: occurrence_path(@occurrence)) do
          span(class: "glyphicon glyphicon-th-large")
          plain(" ")
          plain(:show_observation_matching_observations.l)
        end
      else
        a(href: new_occurrence_path(observation_id: @obs.id)) do
          span(class: "glyphicon glyphicon-th-large")
          plain(" ")
          plain(:show_observation_add_matching_observations.l)
        end
      end
    end

    def render_body
      ul(class: "tight-list") do
        @siblings.each do |sibling|
          li do
            a(href: permanent_observation_path(sibling.id)) do
              trusted_html(sibling.unique_format_name.t)
            end
          end
        end
      end
    end
  end
end
