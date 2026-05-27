# frozen_string_literal: true

# Phlex view for the "add or remove observations" page. Linked from
# observations#index and species_lists#show; renders the inline
# `Form` that posts a chosen species list as the destination for the
# current query of observations.
module Views::Controllers::SpeciesLists::Observations
  class Edit < Views::Base
    register_value_helper :species_list_form_observations_tabs

    def initialize(prefill_value:, num_results:)
      super()
      @prefill_value = prefill_value
      @num_results = num_results
    end

    def view_template
      add_page_title(:species_list_add_remove_title.t)
      add_context_nav(species_list_form_observations_tabs)
      # Sibling reference within the module.
      render(Form.new(
               prefill_value: @prefill_value,
               num_results: @num_results
             ))
    end
  end
end
