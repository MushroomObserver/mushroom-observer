# frozen_string_literal: true

# Action view for the species_list new page. Sets page chrome
# (title, context-nav, container width) and delegates body to the
# shared `Form` Phlex class with `button: :create`.
#
# `clone_id` is set when the user lands on `?clone=<id>` — the form
# pre-populates from another species_list.
module Views::Controllers::SpeciesLists
  class New < Views::FullPageBase
    # rubocop:disable Metrics/ParameterLists
    # See `Edit#initialize` — action views forward whatever the form
    # needs; `ParameterLists` isn't on the CLAUDE.md "always refactor"
    # list and the alternatives (hash collapse, pre-built form) hurt
    # readability.
    def initialize(species_list:, projects:, dubious_where_reasons:,
                   submitted_project_ids:, user:, clone_id: nil)
      super()
      @species_list = species_list
      @projects = projects
      @dubious_where_reasons = dubious_where_reasons
      @submitted_project_ids = submitted_project_ids
      @user = user
      @clone_id = clone_id
    end
    # rubocop:enable Metrics/ParameterLists

    def view_template
      add_new_title(:create_object, :species_list)
      add_context_nav(::Tab::SpeciesList::FormNew.new(q_param: q_param))
      container_class(:text)

      render(Views::Controllers::SpeciesLists::Form.new(
               @species_list,
               projects: @projects,
               dubious_where_reasons: @dubious_where_reasons,
               submitted_project_ids: @submitted_project_ids,
               user: @user,
               button: :create,
               clone_id: @clone_id
             ))
    end
  end
end
