# frozen_string_literal: true

module Tabs
  module ProjectsHelper
    def project_form_new_tabs
      [projects_index_tab]
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

    def edit_project_alias_tab(project_id, name, id)
      InternalLink::Model.new(
        name, ProjectAlias,
        edit_project_alias_path(project_id:, id:),
        alt_title: :EDIT.t
      ).tab
    end

    def new_project_alias_tab(project_id, target_id, target_type)
      InternalLink::Model.new(
        :ADD.t, ProjectAlias,
        new_project_alias_path(project_id:, target_id:, target_type:),
        html_options: { class: "btn btn-default" }
      ).tab
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
        render(Views::Controllers::Projects::Banner.new(
                 project: project,
                 user: User.current,
                 current_tab: active_project_tab
               ))
      end
    end

    def project_species_list_buttons(list, query)
      return unless list

      [project_species_list_map_button(query),
       project_species_list_observations_button(query),
       project_species_list_names_button(list),
       project_species_list_locations_button(query),
       project_species_list_images_button(query)]
    end

    # Shared button shape for the species-list / observations buttons row
    # rendered above an observation listing. Tabs::ProjectsHelper is the
    # last surviving caller of `Components::CrudButton::Get` in btn-frame
    # text-link mode (the `button_link` helper used to wrap this), so the
    # styling lives here rather than as a CrudButton default.
    def project_button(name, path)
      render(Components::CrudButton::Get.new(
               name: name,
               target: path,
               btn: "btn btn-default",
               class: "btn-lg my-3 mr-3"
             ))
    end

    def project_species_list_map_button(query)
      project_button(:MAP.l, add_q_param(map_observations_path, query))
    end

    def project_species_list_observations_button(query)
      project_button(:OBSERVATIONS.l, add_q_param(observations_path, query))
    end

    def project_species_list_names_button(list)
      project_button(:NAMES.l, checklist_path(species_list_id: list.id))
    end

    def project_species_list_locations_button(query)
      return unless query && Query.related?(:Location, :Observation)

      locations_url = InternalLink::RelatedQuery.new(
        Location, :Observation, query, controller
      ).url
      project_button(:LOCATIONS.l, locations_url)
    end

    def project_species_list_images_button(query)
      return unless query && Query.related?(:Location, :Observation)

      images_url = InternalLink::RelatedQuery.new(
        Image, :Observation, query, controller
      ).url
      project_button(:IMAGES.l, images_url)
    end

    def project_observation_buttons(project, query)
      return unless project

      _img_name, img_link, = related_images_tab(:Observation, query)
      buttons = [
        project_button(:MAP.t, add_q_param(map_observations_path, query)),
        project_button(:IMAGES.l, img_link),
        project_button(:DOWNLOAD.l,
                       add_q_param(new_observations_download_path, query))
      ]
      if project.field_slip_prefix
        buttons << project_button(:FIELD_SLIPS.t,
                                  field_slips_path(project:))
      end

      # Download Observations
      content_for(:observation_buttons) do
        tag.div(safe_join(buttons))
      end
    end
  end
end
