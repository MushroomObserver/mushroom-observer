# frozen_string_literal: true

module Views::Controllers::SpeciesLists::Projects
  # Inline form for attaching / removing a species list (and
  # optionally its observations and images) to / from a chosen set
  # of projects. Posts to
  # `SpeciesLists::ProjectsController#update` via PUT under the
  # `species_list_projects[*]` namespace.
  class Form < ::Components::ApplicationForm
    def initialize(list:, projects:, object_states:, project_states:, **)
      @list = list
      @projects = projects
      @object_states = object_states
      @project_states = project_states
      super(build_form_object,
            id: "species_list_projects_form",
            method: :put,
            **)
    end

    def view_template
      super do
        render_object_checkboxes
        render_project_checkboxes
        render_submit_buttons
      end
    end

    private

    def build_form_object
      FormObject::SpeciesListProjects.new(
        objects_list: @object_states[:list] ? "1" : "0",
        objects_obs: @object_states[:obs] ? "1" : "0",
        objects_img: @object_states[:img] ? "1" : "0",
        project_ids: @project_states.select { |_id, on| on }.keys.map(&:to_s)
      )
    end

    def render_object_checkboxes
      div(class: "form-group form-inline mt-3") do
        label(for: "species_list_projects_objects_list") do
          plain(:species_list_projects_which_objects.t)
        end
        checkbox_field(:objects_list,
                       label: :species_list_projects_this_list.t,
                       checked_value: "1", unchecked_value: "0")
        checkbox_field(:objects_obs,
                       label: :species_list_projects_observations.t,
                       checked_value: "1", unchecked_value: "0")
        checkbox_field(:objects_img,
                       label: :species_list_projects_images.t,
                       checked_value: "1", unchecked_value: "0")
      end
    end

    def render_project_checkboxes
      div(class: "form-group form-inline mt-3") do
        label(for: "species_list_projects_project_ids") do
          plain(:species_list_projects_which_projects.t)
        end
        # Array-mode checkboxes: each renders
        # `<input type="checkbox" name="...[project_ids][]" value="<id>">`
        # so the controller receives `project_ids: ["1", "2", ...]`.
        # Rails-shape `[label, value]` pairs.
        options = @projects.sort_by(&:text_name).map do |proj|
          [proj.title.t, proj.id.to_s]
        end
        checkbox_field(:project_ids, *options)
      end
    end

    def render_submit_buttons
      div(class: "text-center mt-3") do
        submit(:ATTACH.l)
        whitespace
        submit(:REMOVE.l)
      end
    end

    def form_action
      url_for(controller: "/species_lists/projects",
              action: :update, id: @list.id, only_path: true)
    end
  end
end
