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
      links << destroy_project_tab(project) if check_permission(project)
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
      return unless check_permission(project)

      # Note this is just an edit_project_tab with different wording
      links << change_member_status_tab(project)
    end

    def projects_index_tab
      InternalLink.new(:app_list_projects.t, projects_path).tab
    end

    def new_project_tab
      InternalLink.new(:list_projects_add_project.t,
                       add_query_param(new_project_path)).tab
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
      add_page_title(link_to_object(project))

      if project.location
        content_for(:location) do
          tag.b(link_to(project.place_name, location_path(project.location.id)))
        end
      end

      if project.start_date && project.end_date
        content_for(:date_range) do
          tag.b(project.date_range)
        end
      end

      add_background_image(project.image)
      project_tabs(project)
    end

    def add_background_image(image)
      return unless image

      content_for(:background_image) do
        image_tag(image.large_url, class: "image-title")
      end
    end

    def build_tab(link_text, link, controller)
      tag.li(class: "nav-item") do
        classes = "mt-3 nav-link #{"active" if active_tab?(controller)}"
        link_to(link_text, link,
                { class: classes })
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

    def project_tabs(project)
      tabs = [build_tab(:SUMMARY.t, project_path(id: project.id), "projects")]
      tabs += observation_tabs(project)

      content_for(:project_tabs) do
        tag.ul(safe_join(tabs), class: "nav nav-tabs")
      end
    end

    def observation_tabs(project)
      tabs = []
      if project.observations.any?
        tabs << build_tab("#{project.observations.length} #{:OBSERVATIONS.l}",
                          observations_path(project:),
                          "observations")
        tabs << build_tab("#{project.species_lists.length} #{:SPECIES_LISTS.l}",
                          species_lists_path(project:),
                          "species_lists")
        tabs << build_tab("#{project.name_count} #{:NAMES.l}",
                          checklist_path(project_id: project.id), "checklists")
        tabs << build_tab("#{project.location_count} #{:LOCATIONS.l}",
                          project_locations_path(project_id: project.id),
                          "locations")
      end
      tabs
    end

    # Helper method to determine active tab
    def active_tab?(tab_name)
      current_tab = controller_name
      if current_tab == "checklists" && params.include?("location_id")
        current_tab = "locations"
      end
      current_tab == tab_name
    end

    def project_species_list_buttons(list, query)
      return unless list

      [project_species_list_map_button(query),
       project_species_list_observations_button(query),
       project_species_list_names_button(list),
       project_species_list_locations_button(query),
       project_species_list_images_button(query)]
    end

    def button_link(title, path)
      styling = { class: "btn btn-default btn-lg my-3 mr-3" }
      link_to(title, path, styling)
    end

    def project_species_list_map_button(query)
      button_link(:MAP.t,
                  add_query_param(map_observations_path, query))
    end

    def project_species_list_observations_button(query)
      button_link(:OBSERVATIONS.t,
                  add_query_param(observations_path, query))
    end

    def project_species_list_names_button(list)
      button_link(:NAMES.t,
                  checklist_path(species_list_id: list.id))
    end

    def project_species_list_locations_button(query)
      return unless query && Query.related?(:Location, :Observation)

      button_link(:LOCATIONS.t,
                  InternalLink::RelatedQuery.new(Location, :Observation,
                                                 query, controller).url)
    end

    def project_species_list_images_button(query)
      return unless query && Query.related?(:Location, :Observation)

      button_link(:IMAGES.t,
                  InternalLink::RelatedQuery.new(Image, :Observation,
                                                 query, controller).url)
    end

    def project_observation_buttons(project, query)
      return unless project

      _img_name, img_link, = related_images_tab(:Observation, query)
      buttons = [
        button_link(:MAP.t,
                    map_observations_path(q: get_query_param(query))),
        button_link(:IMAGES.l, img_link),
        button_link(:DOWNLOAD.l,
                    add_query_param(new_observations_download_path, query))
      ]
      if project.field_slip_prefix
        buttons << button_link(:FIELD_SLIPS.t,
                               field_slips_path(project:))
      end

      # Download Observations
      content_for(:observation_buttons) do
        tag.div(safe_join(buttons))
      end
    end
  end
end
