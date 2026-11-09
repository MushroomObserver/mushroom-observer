# frozen_string_literal: true

module Views::Controllers::SpeciesLists::Projects
  # Inline form for attaching / removing a species list (and
  # optionally its observations and images) to / from a chosen set
  # of projects. Posts to
  # `SpeciesLists::ProjectsController#update` via PUT under the
  # `species_list_projects[*]` namespace.
  class Form < ::Components::ApplicationForm
    prop :list, ::SpeciesList
    prop :projects, _Array(::Project)
    prop :object_states, _Hash(Symbol, _Boolean)
    prop :project_states, _Hash(Integer, _Boolean)

    def initialize(list:, projects:, object_states:, project_states:,
                   **attrs)
      super(build_form_object(object_states, project_states),
            list: list, projects: projects, object_states: object_states,
            project_states: project_states,
            id: "species_list_projects_form",
            method: :put,
            **attrs)
    end

    def view_template
      super do
        render_object_checkboxes
        render_project_checkboxes
        render_submit_buttons
      end
    end

    private

    def build_form_object(object_states, project_states)
      FormObject::SpeciesListProjects.new(
        objects: object_states.select { |_type, on| on }.keys.map(&:to_s),
        project_ids: project_states.select { |_id, on| on }.keys.map(&:to_s)
      )
    end

    def render_object_checkboxes
      div(class: "form-group mt-3") do
        label { plain(:species_list_projects_which_objects.t) }
        checkbox_field(:objects,
                       [:species_list_projects_this_list.t, "list"],
                       [:species_list_projects_observations.t, "obs"],
                       [:species_list_projects_images.t, "img"])
      end
    end

    # No Panel wrap here -- this is a one-page attach/remove utility,
    # not a form full of other fields, so a plain heading + the
    # overflow-scrolled list is enough.
    def render_project_checkboxes
      div(class: "form-group mt-3") do
        label { plain(:species_list_projects_which_projects.t) }
        render(Components::Form::OverflowCheckboxList.new(
                 form: self,
                 type: :project,
                 form_object_name: "species_list_projects",
                 objects: @projects,
                 checked_ids: checked_project_ids
               ))
      end
    end

    def checked_project_ids
      @project_states.select { |_id, on| on }.keys
    end

    def render_submit_buttons
      div(class: "text-center mt-3") do
        submit(:attach.ti)
        whitespace
        submit(:remove.ti)
      end
    end

    def form_action
      url_for(controller: "/species_lists/projects",
              action: :update, id: @list.id, only_path: true)
    end
  end
end
