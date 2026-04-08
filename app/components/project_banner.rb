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
    prop :user, _Nilable(User), default: nil
    prop :on_project_page, _Boolean, default: false
    prop :current_tab, _Nilable(String), default: nil

    def view_template
      return unless @project

      if @project.image
        render_banner_with_image
      else
        render_banner_without_image
      end

      div(class: "row") do
        render(Components::Projects::Tabs.new(
                 project: @project, user: @user,
                 current_tab: @current_tab
               ))
      end
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
            show_title_id_badge(@project)
            plain(" ")
            link_to_object(@project)
            show_page_edit_icons
          end
        else
          link_to_object(@project)
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
  end
end
