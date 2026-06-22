# frozen_string_literal: true

# One species_list "listing" row, rendered inside a
# `Components::ListGroup::Base#item`. Used by:
#   - `Views::Controllers::SpeciesLists::Index#render_list` (the
#     species_lists index page)
#   - `observations/species_lists/edit.rb` (the
#     "manage species lists for this observation" page)
# Title row + place / user row on the left, optional REMOVE / ADD
# button on the right (mutually exclusive, driven by which page the
# listing renders on). Emits contents only — no list-group-item
# wrapper of its own; the surrounding ListGroup item provides it.
module Views::Controllers::SpeciesLists
  class Listing < Views::Base
    def initialize(species_list:, observation: nil,
                   remove: false, add: false, project: nil)
      super()
      @species_list = species_list
      @observation = observation
      @remove = remove
      @add = add
      @project = project
    end

    # Row contents only — the surrounding `<div class="list-group-item
    # d-flex justify-content-between align-items-start">` is emitted by
    # `Components::ListGroup::Base#item` in the Index view.
    def view_template
      render_info
      render_manage_section if @remove || @add
    end

    private

    # `place_name.t` can blow up on lists without a place -
    # `rescue :UNKNOWN.l` is fallback.
    def place
      @place ||= begin
                   @species_list.place_name.t
                 rescue StandardError
                   :UNKNOWN.l
                 end
    end

    def render_info
      div(class: "list_info d-flex align-items-start") do
        div(class: "text-larger") do
          render(Components::IdBadge.new(
                   object: @species_list, extra_class: "rss-id mr-4"
                 ))
        end
        div do
          render_title_row
          render_place_user_row
        end
      end
    end

    def render_title_row
      div do
        link_to(@species_list.show_link_with_project(@project)) do
          span(class: "list_what h4") do
            trusted_html(@species_list.text_name.t)
          end
        end
        whitespace
        span(class: "list_when ml-4") { plain("(#{@species_list.when})") }
      end
    end

    def render_place_user_row
      div do
        # `place_name.t` returns a textile-rendered SafeBuffer — use
        # `trusted_html` so Phlex doesn't double-escape the `&#8216;`
        # smart-quote entities Textile emits.
        span { trusted_html(place) }
        whitespace
        plain("|")
        whitespace
        render(Components::Link::User.new(user: @species_list.user))
      end
    end

    def render_manage_section
      div(class: "list_manage") do
        if @remove
          render_remove_obs_button
        elsif @add
          render_add_obs_button
        end
      end
    end

    def render_remove_obs_button
      render(Components::Button.new(
               type: :put,
               variant: :strip,
               name: :REMOVE.t,
               target: observation_species_list_path(
                 id: @observation.id,
                 species_list_id: @species_list.id,
                 commit: "remove"
               ),
               confirm: :are_you_sure.l
             ))
    end

    def render_add_obs_button
      render(Components::Button.new(
               type: :put,
               name: :ADD.t,
               target: observation_species_list_path(
                 id: @observation.id,
                 species_list_id: @species_list.id,
                 commit: "add"
               )
             ))
    end
  end
end
