# frozen_string_literal: true

# Action template for `Observations::SpeciesListsController#edit` —
# the "manage species lists for this observation" page. Replaces
# `edit.html.erb`. Renders two `Components::ListGroup`s of
# `SpeciesLists::Listing` rows: lists the observation already
# belongs to (REMOVE button on each) and lists it doesn't (ADD
# button on each).
module Views::Controllers::Observations::SpeciesLists
  class Edit < Views::Base
    prop :observation, ::Observation
    prop :all_lists, ::Query::SpeciesLists
    prop :obs_lists, _Array(::SpeciesList)
    prop :other_lists, _Array(::SpeciesList)

    def view_template
      add_page_title(
        :species_list_manage_title.t(
          name: @observation.unique_format_name
        )
      )
      # Sort table lives on `SpeciesListsController` (single
      # source of truth — same one the species_lists index uses).
      # Class-level cousin so we don't have to instantiate.
      add_sorter(
        @all_lists,
        ::SpeciesListsController.sort_options(query: @all_lists)
      )
      add_context_nav(
        Tab::Observation::ListActions.new(observation: @observation)
      )
      container_class(:wide)
      content_padding(:panels)

      div(class: "navbar-flex mb-2") { content_for(:sorter) }

      render(Components::ContentPadded.new) { render_sections }
    end

    private

    def render_sections
      render_section(
        heading: :species_list_manage_belongs_to.l,
        lists: @obs_lists, remove: true
      )
      render_section(
        heading: :species_list_manage_doesnt_contain.l,
        lists: @other_lists, add: true
      )
    end

    # Skip the heading + the list-group entirely when the source
    # array is empty (matches the ERB's `if @obs_lists.any?` /
    # `if @other_lists.any?` guards).
    def render_section(heading:, lists:, remove: false, add: false)
      return if lists.empty?

      h5(class: "mt-3") { plain("#{heading}:") }
      render(Components::ListGroup.new) do |list|
        lists.each do |sl|
          list.item(
            class: "d-flex justify-content-between align-items-start"
          ) do
            render_listing(species_list: sl, remove: remove, add: add)
          end
        end
      end
    end

    def render_listing(species_list:, remove:, add:)
      render(
        Views::Controllers::SpeciesLists::Listing.new(
          species_list: species_list,
          observation: @observation,
          remove: remove && permission?(species_list),
          add: add && permission?(species_list)
        )
      )
    end
  end
end
