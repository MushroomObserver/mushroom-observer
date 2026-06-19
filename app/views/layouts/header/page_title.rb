# frozen_string_literal: true

# Page-title strip below the top nav, rendered on non-index actions.
# Two columns:
#
#   - left: `<h1 id="title">` (consensus title from content_for(:title))
#     plus the edit-icons strip; on obs show, the owner-naming line
#     (separate content_for(:owner_naming)) hangs below the h1.
#   - right (show-only, non-project): interest-icons strip and the
#     prev/index/next pager.
#
# `show_page_edit_icons` / `show_page_interest_icons` are private
# methods on this view — the only caller of either.
module Views::Layouts
  class Header::PageTitle < Views::Base
    SHOW_TITLE_CLASSES =
      "show_title_nav d-flex justify-content-between pl-3"

    EDIT_ICONS_CLASSES = %w[
      nav d-flex align-items-center justify-content-end mt-0 h4 object_edit
    ].freeze

    INTEREST_ICONS_CLASSES = "nav navbar-flex interest-eyes h4 my-0"

    def view_template
      div(class: "row", id: "title_bar") do
        render_left_column unless suppress_title?
        render_right_column if show_right_column?
      end
    end

    private

    def render_left_column
      div(class: content_for(:left_columns).to_s) do
        nav(class: SHOW_TITLE_CLASSES) do
          h1(class: "h3 page-title mt-3 mb-4", id: "title") do
            trusted_html(content_for(:title))
          end
          render_edit_icons
        end
        trusted_html(content_for(:owner_naming)) if content_for?(:owner_naming)
      end
    end

    def render_right_column
      div(class: class_names(content_for(:right_columns),
                             "hidden-print text-right")) do
        nav(class: "show_object_nav d-flex justify-content-between pr-3") do
          render_interest_icons
          trusted_html(content_for(:prev_next_object))
        end
      end
    end

    # Always-rendered <ul> even when no edit icons are queued — the
    # flex layout reserves the right-side slot so titles don't
    # jitter left when icons appear/disappear across pages.
    def render_edit_icons
      ul(class: class_names(EDIT_ICONS_CLASSES)) do
        trusted_html(content_for(:edit_icons)) if content_for?(:edit_icons)
      end
    end

    def render_interest_icons
      ul(class: INTEREST_ICONS_CLASSES) do
        if content_for?(:interest_icons)
          trusted_html(content_for(:interest_icons))
        end
      end
    end

    def suppress_title?
      controller.action_name == "index" || on_project_page?
    end

    def show_right_column?
      controller.action_name == "show" && !on_project_page?
    end

    # Projects render their own title inside ProjectBanner — skip
    # ours to avoid stacking two titles.
    def on_project_page?
      return false unless content_for?(:project_banner)

      path = controller.controller_path
      path == "projects" || path.start_with?("projects/")
    end
  end
end
