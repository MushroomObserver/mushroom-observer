# frozen_string_literal: true

# Action template for `Observations::SpeciesListsController#edit` —
# the "manage species lists for this observation" page. Mirrors
# `Observations::Projects::Edit`, sharing
# `Components::ObservationListManager` for the two-section layout.
# Rows are `SpeciesLists::Listing`: lists the observation already
# belongs to (REMOVE button on each) and lists it doesn't (ADD
# button on each).
module Views::Controllers::Observations::SpeciesLists
  class Edit < Views::FullPageBase
    prop :observation, ::Observation
    prop :all_lists, ::Query::SpeciesLists
    prop :obs_lists, _Array(::SpeciesList)
    prop :other_lists, _Array(::SpeciesList)

    def view_template
      add_page_title(
        :species_list_manage_title.t(
          name: viewer_aware_unique_format_name(@observation)
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
      add_pagination(nil)
      container_class(:wide)
      content_padding(:panels)

      PaginatedResults { render_manager }
    end

    private

    def render_manager
      ObservationListManager(
        belongs_to_heading: :species_list_manage_belongs_to.l,
        belongs_to_items: @obs_lists,
        not_contains_heading: :species_list_manage_doesnt_contain.l,
        not_contains_items: @other_lists
      ) do |species_list, remove, add|
        render_listing(species_list: species_list, remove: remove, add: add)
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
