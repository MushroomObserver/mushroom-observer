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

    prop :project, _Nilable(Project)
    prop :on_project_page, _Boolean, default: false
    prop :current_tab, _Nilable(String), default: nil

    def view_template
      return unless @project

      if @project.image
        render_banner_with_image
      else
        render_banner_without_image
      end

      render_project_tabs if project_has_content?
    end

    private

    def render_banner_with_image
      div(class: "row") do
        div(class: "col-xs-12", id: "project_banner") do
          img(src: @project.image.large_url, class: "banner-image")
          div(class: "bottom-left ml-3 mb-3 p-2") do
            render_banner_title_with_icons(with_overlay_styling: true)
            render_project_location(with_overlay_styling: true)
            render_project_date_range(with_overlay_styling: true)
          end
        end
      end
    end

    def render_banner_without_image
      div(class: "row") do
        div(class: "col-xs-12", id: "project_banner") do
          div(class: "pl-3 mt-3") do
            render_banner_title_with_icons(with_overlay_styling: false)
          end
          if project_subtitle?
            div(class: "pl-3 mb-3") do
              render_project_location(with_overlay_styling: false)
              render_project_date_range(with_overlay_styling: false)
            end
          end
        end
      end
    end

    def render_banner_title_with_icons(with_overlay_styling:)
      title_classes = if with_overlay_styling
                        "h3 banner-image-text"
                      else
                        "h3 page-title mb-4"
                      end

      h1(class: title_classes, id: title_id) do
        if @on_project_page
          div(class: "d-flex align-items-center") do
            trusted_html(show_title_id_badge(@project))
            plain(" ")
            trusted_html(link_to_object(@project))
            trusted_html(show_page_edit_icons)
          end
        else
          trusted_html(link_to_object(@project))
        end
      end
    end

    def project_subtitle?
      @project.location || (@project.start_date && @project.end_date)
    end

    def title_id
      @on_project_page ? "title" : "banner_title"
    end

    def render_project_location(with_overlay_styling:)
      return unless @project.location

      location_classes = if with_overlay_styling
                           "project_location banner-image-text"
                         else
                           "project_location"
                         end

      div(class: location_classes) do
        b do
          a(href: location_path(@project.location.id)) do
            @project.place_name
          end
        end
      end
    end

    def render_project_date_range(with_overlay_styling:)
      return unless @project.start_date && @project.end_date

      date_classes = if with_overlay_styling
                       "project_date_range banner-image-text"
                     else
                       "project_date_range"
                     end

      div(class: date_classes) do
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
      observations_tab
      species_lists_tab
      names_tab
      locations_tab
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
      tab_item(
        "#{@project.species_lists.length} #{:SPECIES_LISTS.l}",
        species_lists_path(project: @project),
        "species_lists"
      )
    end

    def tab_item(text, path, tab_name)
      li(class: "nav-item") do
        a(href: path, class: tab_classes(tab_name)) { text }
      end
    end

    def tab_classes(tab_name)
      base = "mt-3 nav-link"
      "#{base} #{"active" if active_tab?(tab_name)}"
    end

    def active_tab?(tab_name)
      @current_tab == tab_name
    end

    def project_has_content?
      @project.observations.any? || @project.species_lists.any?
    end
  end
end
