# frozen_string_literal: true

module Views::Controllers::SpeciesLists::Downloads
  # Form for printing labels for species list observations.
  # Rendered by `species_lists/downloads/new.rb`.
  #
  # @example
  #   render(Views::Controllers::SpeciesLists::Downloads::Form.new(
  #     query: @query
  #   ))
  class Form < ::Components::ApplicationForm
    prop :query, _Nilable(::Query), default: nil

    def initialize(query: nil, **attrs)
      # Permanently local: true -- always send_data (a labels PDF)
      # (see .claude/rules/turbo_submit_forms.md). local: true comes
      # after **attrs so no caller can override it.
      super(FormObject::PrintLabels.new,
            query: query,
            id: "species_list_download_print_labels", **attrs, local: true)
    end

    def view_template
      super do
        h3(class: "mt-5") { "#{:species_list_labels_header.l}:" }
        submit(:species_list_labels_button.l, center: true)
      end
    end

    private

    def form_action
      print_labels_for_observations_path(q: q_param(@query))
    end
  end
end
