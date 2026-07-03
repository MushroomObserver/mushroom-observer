# frozen_string_literal: true

# Renders a project banner with title, location, date range, tabs,
# and optional banner image. Rendered on every project page (and
# the per-project checklist show page) via the `add_project_banner`
# helper so the banner looks the same regardless of which tab is
# selected.
#
# @example Basic usage in helper
#   content_for(:project_banner) do
#     render(Views::Controllers::Projects::Banner.new(project: @project))
#   end
module Views::Controllers::Projects
  class Banner < Views::Base
    include Phlex::Rails::Helpers::ContentFor

    prop :project, _Nilable(Project)
    prop :user, _Nilable(User), default: nil
    prop :current_tab, _Nilable(String), default: nil

    def view_template
      return unless @project

      if @project.image
        render_banner_with_image
      else
        render_banner_without_image
      end

      div(class: "row") do
        div(class: Grid::FULL, id: "project_tabs") do
          NavTabs(
            current: @current_tab, link_class: "mt-3",
            tabs: ::Tab::Project::Banner.new(
              project: @project, user: @user
            )
          )
        end
      end
    end

    private

    def render_banner_with_image
      div(class: "row") do
        div(class: Grid::FULL, id: "project_banner") do
          img(src: @project.image.large_url, class: "banner-image")
          div(class: "bottom-left ml-3 mb-3 p-2") do
            render_banner_title(with_overlay_styling: true)
            render_project_location(with_overlay_styling: true)
            render_project_date_range(with_overlay_styling: true)
          end
        end
      end
    end

    def render_banner_without_image
      div(class: "row") do
        div(class: Grid::FULL, id: "project_banner") do
          div(class: "pl-3 mt-3") do
            render_banner_title(with_overlay_styling: false)
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

    def render_banner_title(with_overlay_styling:)
      title_classes = if with_overlay_styling
                        "h3 banner-image-text"
                      else
                        "h3 page-title mb-4"
                      end

      h1(class: title_classes, id: "title") do
        div(class: "d-flex align-items-center") do
          IdBadge(object: @project)
          whitespace
          Link(type: :object, object: @project)
        end
      end
    end

    def project_subtitle?
      @project.location || (@project.start_date && @project.end_date)
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
