# frozen_string_literal: true

# Page-title strip below the top nav, rendered on non-index actions.
# Two columns on `sm`+:
#
#   - left: the id badge, `<h1 id="title">` (consensus title from
#     content_for(:title), including, on obs show, the owner-naming
#     line -- see `Views::Layouts::Header::ObjectTitle`), a CTA slot
#     right after the title (a form's primary submit button), and the
#     actions slot flush right (edit/destroy icons).
#   - right (show-only, non-project, and only when the page has a
#     column split -- see `columns?`): interest-icons strip and
#     the prev/index/next pager. On a column-less show page, that
#     same content renders inline in the left column instead, right
#     before the edit/destroy icons (`render_inline_object_nav`).
#
# Below `sm`, those two columns collapse to `d-none` and a third
# piece, `render_mobile_top_row`, takes over: the id badge, CTA,
# actions, and interest-icons/pager all on one line, with the object
# name/owner-naming (the unchanged left-column `<h1>`) on a separate
# line below. The mobile row duplicates that markup rather than
# reordering it in place -- none of those pieces emits an HTML `id`,
# so the duplication is safe (see
# `Views::FullPageBase::Title#add_id_badge`).
#
# Neither `.show_title_nav` (title + actions) nor `.show_object_nav`
# (interest-icons + pager) is a `<nav>` landmark -- neither holds only
# navigation content. The `<nav>` landmark in this strip is supplied
# by `Views::Layouts::Header::ShowPrevNextNav`, around the pager alone.
#
# `#title_bar` and `#content` share the same `content_for(:container_class)`
# width cap (`container-text`, `container-wide`, ...), applied once by
# `Views::Layouts::Application#render_header_and_main` around both --
# this component doesn't apply it itself, so a narrow-width page's
# title lines up with its body instead of spanning the full column.
module Views::Layouts
  class Header::PageTitle < Views::Base
    SHOW_TITLE_CLASSES =
      "show_title_nav d-flex justify-content-start align-items-start " \
      "px-card"

    def view_template
      Row(id: "title_bar", class: "mb-1") do
        render_mobile_top_row unless suppress_title?
        render_left_column unless suppress_title?
        render_right_column if show_desktop_right_column?
      end
    end

    private

    def render_mobile_top_row
      return unless mobile_top_row_content?

      Column(xs: 12,
             class: Components::Column.mobile_only_classes(hide_at: :sm)) do
        div(class: "d-flex flex-wrap justify-content-between " \
                   "align-items-center px-card mb-2") do
          trusted_html(content_for(:id_badge))
          trusted_html(content_for(:title_bar_cta))
          trusted_html(content_for(:title_bar_actions))
          render_mobile_object_nav if object_nav?
        end
      end
    end

    # An unconditional wrapper here left an empty row on pages with
    # none of these pieces (e.g. `new`) -- same bug `render_id_badge`
    # already guards against, one level up.
    def mobile_top_row_content?
      content_for?(:id_badge) || content_for?(:title_bar_cta) ||
        content_for?(:title_bar_actions) || object_nav?
    end

    def render_mobile_object_nav
      trusted_html(content_for(:interest_icons))
      trusted_html(content_for(:prev_next_object))
    end

    def render_left_column
      div(class: class_names(content_for(:left_columns),
                             "title_bar_left_col")) do
        div(class: SHOW_TITLE_CLASSES) do
          render_id_badge
          h1(class: "h3 page-title mt-1 mb-2", id: "title") do
            trusted_html(content_for(:title))
          end
          render_title_bar_cta
          render_title_bar_actions
        end
      end
    end

    # `add_id_badge` (`Views::FullPageBase::Title`) only runs for
    # show/edit pages with an object; an unconditional wrapper here
    # left an empty `mr-3`-margined div on pages with neither (`new`).
    def render_id_badge
      return unless content_for?(:id_badge)

      div(class: "id_badge_wrap d-none d-sm-block mr-3 mt-sm-2") do
        trusted_html(content_for(:id_badge))
      end
    end

    # A form's primary submit button -- right after the title, the
    # clearest spot for a call to action. Associates with the `<form>`
    # via `form:` rather than nesting the title bar inside it -- see
    # `Components::ApplicationForm::FieldHelpers#title_bar_submit`.
    def render_title_bar_cta
      return unless content_for?(:title_bar_cta)

      div(class: "title_bar_cta_wrap d-none d-sm-block ml-3") do
        trusted_html(content_for(:title_bar_cta))
      end
    end

    # On a page with no columns, interest-icons + the prev/next pager
    # have no right column to render into (see render_right_column) --
    # show them here instead, right before the edit/destroy icons,
    # with a gap between the two groups.
    def render_title_bar_actions
      inline = inline_object_nav?
      return unless content_for?(:title_bar_actions) || inline

      div(class: "title_bar_actions_wrap d-none d-sm-flex ml-auto " \
                 "flex-nowrap flex-shrink-0 align-items-start") do
        render_inline_object_nav if inline
        trusted_html(content_for(:title_bar_actions)) if
          content_for?(:title_bar_actions)
      end
    end

    def render_inline_object_nav
      div(class: "d-flex flex-nowrap flex-shrink-0 align-items-start mr-3") do
        trusted_html(content_for(:interest_icons))
        trusted_html(content_for(:prev_next_object))
      end
    end

    def render_right_column
      div(class: class_names(content_for(:right_columns),
                             "title_bar_right_col hidden-print " \
                             "text-right d-none d-sm-block")) do
        div(class: "show_object_nav d-flex justify-content-between " \
                   "align-items-start px-card") do
          div { trusted_html(content_for(:interest_icons)) }
          trusted_html(content_for(:prev_next_object))
        end
      end
    end

    def suppress_title?
      controller.action_name == "index" || on_project_page?
    end

    # A right column to render interest-icons/pager into only exists
    # when the page opted into a column split (see
    # Views::FullPageBase::LayoutClasses#column_classes) -- a
    # column-less show page (SpeciesLists) renders the same content
    # inline instead, via render_inline_object_nav.
    def show_desktop_right_column?
      object_nav? && columns?
    end

    def inline_object_nav?
      object_nav? && !columns?
    end

    def columns?
      content_for?(:has_columns)
    end

    def object_nav?
      controller.action_name == "show" && !on_project_page? &&
        right_column_content?
    end

    # Only Locations/Names/Observations/SpeciesLists show pages call
    # `add_interest_icons`/`add_pager_for` -- every other model's show
    # page would otherwise get an empty flex row here.
    def right_column_content?
      content_for?(:interest_icons) || content_for?(:prev_next_object)
    end

    # `projects#show` renders a title inside ProjectBanner — skip ours
    # there to avoid stacking two titles. Every other project
    # sub-page (aliases, members, admin, ...) has a distinct heading
    # alongside the banner's project title, so it isn't suppressed.
    def on_project_page?
      return false unless content_for?(:project_banner)

      controller.controller_path == "projects" &&
        controller.action_name == "show"
    end
  end
end
