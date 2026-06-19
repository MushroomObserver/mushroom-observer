# frozen_string_literal: true

module Views::Controllers::SpeciesLists::Downloads
  # Form for printing labels for species list observations.
  # Rendered by `species_lists/downloads/new.rb`.
  #
  # @example
  #   render(Views::Controllers::SpeciesLists::Downloads::Form.new(
  #     query_param: q_param(@query)
  #   ))
  class Form < ::Components::ApplicationForm
    def initialize(query_param:, **)
      @query_param = query_param
      super(FormObject::PrintLabels.new,
            id: "species_list_download_print_labels", **)
    end

    def view_template
      super do
        h3(class: "mt-5") { "#{:species_list_labels_header.l}:" }
        submit(:species_list_labels_button.l, center: true)
      end
    end

    private

    def form_action
      print_labels_for_observations_path(q: @query_param)
    end
  end
end
