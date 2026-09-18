# frozen_string_literal: true

# Page-title strip below the top nav, rendered on non-index actions.
# Two columns on `md`+:
#
#   - left: the id badge, `<h1 id="title">` (consensus title from
#     content_for(:title), including, on obs show, the owner-naming
#     line -- see `Views::Layouts::Header::ObjectTitle`), and the
#     edit-icons strip.
#   - right (show-only, non-project): interest-icons strip and the
#     prev/index/next pager.
#
# Below `md`, those two columns collapse to `d-none` and a third
# piece, `render_mobile_top_row`, takes over: the id badge, edit
# icons, and interest-icons/pager all on one line, with the object
# name/owner-naming (the unchanged left-column `<h1>`) on a separate
# line below. The mobile row duplicates the id-badge/edit-icons/
# interest-icons/pager markup rather than reordering it in place --
# none of those four emits an HTML `id`, so the duplication is safe
# (see `Views::FullPageBase::Title#add_id_badge`).
#
# `show_page_edit_icons` / `show_page_interest_icons` are private
# methods on this view — the only caller of either.
#
# Neither `.show_title_nav` (title + edit-icons) nor `.show_object_nav`
# (interest-icons + pager) is a `<nav>` landmark -- neither holds only
# navigation content. The `<nav>` landmark in this strip is supplied
# by `Views::Layouts::Header::ShowPrevNextNav`, around the pager alone.
module Views::Layouts
  class Header::PageTitle < Views::Base
    SHOW_TITLE_CLASSES =
      "show_title_nav d-flex justify-content-start align-items-start px-card"

    def view_template
      Row(id: "title_bar") do
        render_mobile_top_row unless suppress_title?
        render_left_column unless suppress_title?
        render_right_column if show_right_column?
      end
    end

    private

    # Only visible below `md` (`d-md-none`) -- the `md`+ layout keeps
    # these same four pieces in their desktop positions instead (see
    # `render_left_column`/`render_right_column`). `.col-12` keeps
    # Bootstrap's default column padding rather than `px-card` --
    # `.row`'s negative margin is sized to cancel that default
    # padding, returning the column to the true edge of `#header`.
    # `px-card` goes on the nested div instead, so its inset is added
    # on top of that true edge rather than replacing (and
    # under-shooting) the padding the negative margin depends on.
    def render_mobile_top_row
      div(class: "col-12 d-md-none") do
        div(class: "d-flex flex-wrap justify-content-between " \
                   "align-items-center px-card") do
          trusted_html(content_for(:id_badge))
          trusted_html(content_for(:edit_icons))
          render_mobile_object_nav if show_right_column?
        end
      end
    end

    def render_mobile_object_nav
      trusted_html(content_for(:interest_icons))
      trusted_html(content_for(:prev_next_object))
    end

    def render_left_column
      div(class: content_for(:left_columns).to_s) do
        div(class: SHOW_TITLE_CLASSES) do
          div(class: "d-none d-md-block mr-3 mt-md-1") do
            trusted_html(content_for(:id_badge))
          end
          h1(class: "h3 page-title mt-1 mb-2", id: "title") do
            trusted_html(content_for(:title))
          end
          div(class: "d-none d-md-block ml-auto") do
            trusted_html(content_for(:edit_icons))
          end
        end
      end
    end

    def render_right_column
      div(class: class_names(content_for(:right_columns),
                             "hidden-print text-right d-none d-md-block")) do
        div(class: "show_object_nav d-flex justify-content-between " \
                   "align-items-start pr-3") do
          trusted_html(content_for(:interest_icons))
          trusted_html(content_for(:prev_next_object))
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
