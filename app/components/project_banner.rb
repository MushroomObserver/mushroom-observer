# frozen_string_literal: true

module Components
  # Renders a project banner with title, location, date range,
  # and optional edit icons
  #
  # @example Basic usage in view
  #   <%= render(Components::ProjectBanner.new(
  #     on_project_page: true,
  #     project: @project
  #   )) %>
  #
  # Uses content_for blocks set by helpers:
  #   - :banner_image
  #   - :banner_title
  #   - :edit_icons
  #
  class ProjectBanner < Base
    include Phlex::Rails::Helpers::ContentFor

    prop :on_project_page, _Boolean, default: false
    prop :project, _Nilable(Project), default: nil

    def view_template
      div(class: "row") do
        div(class: "col-xs-12", id: "project_banner") do
          render_banner_image

          div(class: "bottom-left ml-3 mb-3 p-2") do
            render_banner_title
            render_project_location
            render_project_date_range
          end
        end
      end
    end

    private

    def title_id
      @on_project_page ? "title" : "banner_title"
    end

    def render_banner_image
      return unless content_for?(:banner_image)

      trusted_html(content_for(:banner_image))
    end

    def render_banner_title
      h1(class: "h3 banner-image-text", id: title_id) do
        div(class: "d-flex align-items-center") do
          render_title_content
          render_edit_icons
        end
      end
    end

    def render_title_content
      return unless content_for?(:banner_title)

      trusted_html(content_for(:banner_title))
    end

    def render_edit_icons
      return unless @on_project_page && content_for?(:edit_icons)

      ul(class: "nav navbar-nav object_edit h4") do
        trusted_html(content_for(:edit_icons))
      end
    end

    def render_project_location
      return unless @project&.location

      div(class: "project_location banner-image-text") do
        b do
          a(href: location_path(@project.location.id)) do
            @project.place_name
          end
        end
      end
    end

    def render_project_date_range
      return unless @project&.start_date && @project.end_date

      div(class: "project_date_range banner-image-text") do
        b { @project.date_range }
      end
    end
  end
end
