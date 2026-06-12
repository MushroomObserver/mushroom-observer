# frozen_string_literal: true

module Views::Controllers::SpeciesLists::Observations
  # Inline form for adding or removing the current observation query
  # to/from a chosen species list. Posts to
  # `SpeciesLists::ObservationsController#update` via PUT under the
  # `species_list[*]` model namespace.
  #
  # The autocompleter writes to `:title` — the user-typed string or
  # the selected dropdown row's title. The controller's
  # `lookup_species_list_by_id_or_name` accepts either a numeric id
  # or a title, so the field handles both autocompleter selection
  # and direct URL pre-fill (`?species_list[title]=<title-or-id>`).
  class Form < ::Components::ApplicationForm
    def initialize(num_results:, prefill_value: nil, **)
      @num_results = num_results
      super(SpeciesList.new(title: prefill_value),
            id: "species_list_observations_form",
            method: :put,
            **)
    end

    def view_template
      super do
        p { :species_list_add_remove_body.tp(num: @num_results) }
        autocompleter_field(
          :title,
          type: :species_list,
          label: "#{:species_list_add_remove_label.t}:"
        )
        div(class: "form-group center-block") do
          submit(:ADD.l)
          submit(:REMOVE.l)
        end
      end
    end

    private

    def form_action
      url_for(controller: "/species_lists/observations",
              action: :update, only_path: true)
    end
  end
end
