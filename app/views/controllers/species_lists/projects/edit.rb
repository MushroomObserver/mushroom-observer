# frozen_string_literal: true

# Phlex view for the species-list project-management page — page
# chrome plus the inline `Form`.
module Views::Controllers::SpeciesLists::Projects
  class Edit < Views::FullPageBase
    def initialize(list:, projects:, object_states:, project_states:)
      super()
      @list = list
      @projects = projects
      @object_states = object_states
      @project_states = project_states
    end

    def view_template
      add_page_title(:species_list_projects_title.t(list: @list.title))
      add_context_nav(::Tab::SpeciesList::FormEditProject.new(list: @list))

      Help(content: :species_list_projects_help.tp, class: "mt-3")

      # Sibling reference within the namespace.
      render(Form.new(
               list: @list,
               projects: @projects,
               object_states: @object_states,
               project_states: @project_states
             ))
    end
  end
end
