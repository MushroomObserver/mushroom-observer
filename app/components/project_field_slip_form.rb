# frozen_string_literal: true

# Phlex form for creating project field slips.
# Replaces the form_with in projects/field_slips/new.html.erb.
class Components::ProjectFieldSlipForm < Components::ApplicationForm
  register_value_helper :project_field_slips_path

  def initialize(model, project:, **)
    @project = project
    super(model, local: false, **)
  end

  def view_template
    super do
      number_field(:field_slips, label: :field_slips.l,
                                 inline: true, min: 1)
      checkbox_field(:one_per_page,
                     label: :field_slips_one_per_page.t)
      submit(:CREATE.l, class: "ml-3")
    end
  end

  private

  def form_action
    project_field_slips_path(project_id: @project.id)
  end
end
