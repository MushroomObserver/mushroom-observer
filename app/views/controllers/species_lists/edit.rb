# frozen_string_literal: true

# Action view for the species_list edit page. Sets page chrome
# (title, context-nav, container width) and delegates body to the
# shared `Form` Phlex class with `button: :UPDATE`.
module Views::Controllers::SpeciesLists
  class Edit < Views::Base
    def initialize(species_list:, projects:, dubious_where_reasons:,
                   submitted_project_ids:, user:)
      super()
      @species_list = species_list
      @projects = projects
      @dubious_where_reasons = dubious_where_reasons
      @submitted_project_ids = submitted_project_ids
      @user = user
    end

    def view_template
      add_edit_title(@species_list)
      add_context_nav(::Tab::SpeciesList::FormEdit.new(list: @species_list))
      container_class(:text)

      render(Views::Controllers::SpeciesLists::Form.new(
               @species_list,
               projects: @projects,
               dubious_where_reasons: @dubious_where_reasons,
               submitted_project_ids: @submitted_project_ids,
               user: @user,
               button: :UPDATE
             ))
    end
  end
end
