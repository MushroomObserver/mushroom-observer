# frozen_string_literal: true

module Components
  # Renders a project banner with title, location, date range, tabs,
  # and optional banner image
  #
  # @example Basic usage in helper
  #   content_for(:project_banner) do
  #     render(Components::ProjectBanner.new(
  #       project: @project,
  #       on_project_page: true
  #     ))
  #   end
  #
  class ProjectBanner < Base
    include Phlex::Rails::Helpers::ContentFor
    include Rails.application.routes.url_helpers
    include ActionView::Helpers::UrlHelper
    include ActionView::Helpers::AssetUrlHelper
    include ActionView::Helpers::OutputSafetyHelper
    include ObjectLinkHelper
    include Header::TitleHelper

    prop :project, Project
    prop :on_project_page, _Boolean, default: false

    def view_template
      return unless @project

      div(class: "row") do
        div(class: "col-xs-12", id: "project_banner") do
          render_banner_image_or_background
          render_banner_content
        end
      end

      render_project_tabs if project_has_content?
    end

    private

    def render_banner_image_or_background
      if @project.image
        img(src: @project.image.large_url, class: "banner-image")
      else
        # Solid background when no image - styling handled by CSS
        div(class: "banner-background")
      end
    end

    def render_banner_content
      div(class: "bottom-left ml-3 mb-3 p-2") do
        render_banner_title
        render_project_location
        render_project_date_range
      end
    end

    def render_banner_title
      h1(class: "h3 banner-image-text", id: title_id) do
        trusted_html(banner_title_html)
      end
    end

    def banner_title_html
      if @on_project_page
        safe_join([helpers.show_title_id_badge(@project),
                   helpers.link_to_object(@project)],
                  " ")
      else
        helpers.link_to_object(@project)
      end
    end

    def title_id
      @on_project_page ? "title" : "banner_title"
    end

    def render_project_location
      return unless @project.location

      div(class: "project_location banner-image-text") do
        b do
          a(href: location_path(@project.location.id)) do
            @project.place_name
          end
        end
      end
    end

    def render_project_date_range
      return unless @project.start_date && @project.end_date

      div(class: "project_date_range banner-image-text") do
        b { @project.date_range }
      end
    end

    def render_project_tabs
      div(class: "row") do
        div(class: "col-xs-12", id: "project_tabs") do
          ul(class: "nav nav-tabs") do
            summary_tab
            observation_tabs if @project.observations.any?
            species_list_tabs if @project.species_lists.any? &&
                                 @project.observations.empty?
          end
        end
      end
    end

    def summary_tab
      li(class: "nav-item") do
        a(
          href: project_path(id: @project.id),
          class: tab_classes("projects")
        ) { :SUMMARY.t }
      end
    end

    def observation_tabs
      [
        observations_tab,
        species_lists_tab,
        names_tab,
        locations_tab
      ]
    end

    def observations_tab
      tab_item(
        "#{@project.observations.length} #{:OBSERVATIONS.l}",
        observations_path(project: @project),
        "observations"
      )
    end

    def species_lists_tab
      tab_item(
        "#{@project.species_lists.length} #{:SPECIES_LISTS.l}",
        species_lists_path(project: @project),
        "species_lists"
      )
    end

    def names_tab
      tab_item(
        "#{@project.name_count} #{:NAMES.l}",
        checklist_path(project_id: @project.id),
        "checklists"
      )
    end

    def locations_tab
      tab_item(
        "#{@project.location_count} #{:LOCATIONS.l}",
        project_locations_path(project_id: @project.id),
        "locations"
      )
    end

    def species_list_tabs
      [
        tab_item(
          "#{@project.species_lists.length} #{:SPECIES_LISTS.l}",
          species_lists_path(project: @project),
          "species_lists"
        )
      ]
    end

    def tab_item(text, path, controller_name)
      li(class: "nav-item") do
        a(href: path, class: tab_classes(controller_name)) { text }
      end
    end

    def tab_classes(controller_name)
      base = "mt-3 nav-link"
      "#{base} #{"active" if active_tab?(controller_name)}"
    end

    def active_tab?(tab_name)
      current = helpers.controller_name
      current = "locations" if current == "checklists" &&
                               helpers.params.include?("location_id")
      current == tab_name
    end

    def project_has_content?
      @project.observations.any? || @project.species_lists.any?
    end
  end
end
