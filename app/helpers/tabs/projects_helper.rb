# frozen_string_literal: true

module Tabs
  module ProjectsHelper
    def project_form_new_tabs
      [projects_index_tab]
    end

    def project_form_edit_tabs(project:)
      links = [
        projects_index_tab,
        object_return_tab(project)
      ]
      links << destroy_project_tab(project) if permission?(project)
      links
    end

    def projects_index_tabs
      [new_project_tab]
    end

    def project_members_form_new_tabs(project:)
      [object_return_tab(project)]
    end

    def project_member_form_edit_tabs(project:)
      links = [
        projects_index_tab,
        object_return_tab(project)
      ]
      return unless permission?(project)

      # Note this is just an edit_project_tab with different wording
      links << change_member_status_tab(project)
    end

    def projects_index_tab
      InternalLink.new(:cancel_to_index.t(type: :PROJECT), projects_path).tab
    end

    def new_project_tab
      InternalLink.new(:list_projects_add_project.t, new_project_path).tab
    end

    def change_member_status_tab(project)
      InternalLink.new(:change_member_status_edit.t,
                       edit_project_path(project.id)).tab
    end

    def destroy_project_tab(project)
      InternalLink::Model.new(:destroy_object.t(TYPE: Project),
                              project, project,
                              html_options: { button: :destroy }).tab
    end

    def projects_for_user_tab(user)
      InternalLink.new(
        :app_your_projects.l, projects_path(member: user.id)
      ).tab
    end

    # Add some alternate sorting criteria.
    def projects_index_sorts
      [
        ["name", :sort_by_title.l],
        ["created_at",  :sort_by_created_at.l],
        ["updated_at",  :sort_by_updated_at.l],
        ["summary", :sort_by_summary.l]
      ].freeze
    end

    def add_project_banner(project)
      content_for(:project_banner) do
        render(Components::ProjectBanner.new(
                 project: project,
                 on_project_page: controller.controller_name == "projects" &&
                                  action_name == "show"
               ))
      end
    end

    def violations_button(project)
      return unless project.constraints?

      violations_count = project.count_violations
      btn_type = if violations_count.positive?
                   "btn-warning"
                 else
                   "btn-default"
                 end
      classes = "btn btn-lg #{btn_type}"
      link_to("#{violations_count} #{:CONSTRAINT_VIOLATIONS.l}",
              project_violations_path(project_id: project.id),
              { class: classes })
    end

    def project_species_list_buttons(list, query)
      return unless list

      [project_species_list_map_button(query),
       project_species_list_observations_button(query),
       project_species_list_names_button(list),
       project_species_list_locations_button(query),
       project_species_list_images_button(query)]
    end

    def project_button_args
      { class: "btn-lg my-3 mr-3" }
    end

    def project_species_list_map_button(query)
      button_link(:MAP.l, add_q_param(map_observations_path, query),
                  **project_button_args)
    end

    def project_species_list_observations_button(query)
      button_link(:OBSERVATIONS.l, add_q_param(observations_path, query),
                  **project_button_args)
    end

    def project_species_list_names_button(list)
      button_link(:NAMES.l,
                  checklist_path(species_list_id: list.id),
                  **project_button_args)
    end

    def project_species_list_locations_button(query)
      return unless query && Query.related?(:Location, :Observation)

      locations_url = InternalLink::RelatedQuery.new(
        Location, :Observation, query, controller
      ).url
      button_link(:LOCATIONS.l, locations_url, **project_button_args)
    end

    def project_species_list_images_button(query)
      return unless query && Query.related?(:Location, :Observation)

      images_url = InternalLink::RelatedQuery.new(
        Image, :Observation, query, controller
      ).url
      button_link(:IMAGES.l, images_url, **project_button_args)
    end

    def project_observation_buttons(project, query)
      return unless project

      _img_name, img_link, = related_images_tab(:Observation, query)
      buttons = [
        button_link(:MAP.t, add_q_param(map_observations_path, query),
                    **project_button_args),
        button_link(:IMAGES.l, img_link, **project_button_args),
        button_link(:DOWNLOAD.l,
                    add_q_param(new_observations_download_path, query),
                    **project_button_args)
      ]
      if project.field_slip_prefix
        buttons << button_link(:FIELD_SLIPS.t, field_slips_path(project:),
                               **project_button_args)
      end

      # Download Observations
      content_for(:observation_buttons) do
        tag.div(safe_join(buttons))
      end
    end
  end
end
