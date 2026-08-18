# frozen_string_literal: true

# Action template for `Observations::FieldSlipsController#edit` — the
# "attach this observation to a field slip" page. Mirrors
# `Observations::Projects::Edit` / `Observations::SpeciesLists::Edit`,
# scaled down to the single-field form this action needs.
module Views::Controllers::Observations::FieldSlips
  class Edit < Views::FullPageBase
    prop :observation, ::Observation

    def view_template
      add_page_title(
        :field_slip_attach_title.t(
          name: viewer_aware_unique_format_name(@observation)
        )
      )
      add_context_nav(
        Tab::Observation::ListActions.new(observation: @observation)
      )

      div(class: "p-3") do
        render(Form.new(observation: @observation))
      end
    end
  end
end
