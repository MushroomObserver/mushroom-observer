# frozen_string_literal: true

# The header block immediately below the application top nav. Rendered
# once per page by the application layout. Composes (in order):
#
#   - the optional `:project_banner` content_for slot;
#   - on non-index actions, the page title strip
#     (`Header::PageTitle` — replaces `_page_title.erb`);
#   - the project observation-buttons row, fed from a content_for
#     slot.
#
# The index filter/pager bar (`Header::IndexBar`) and the rss-log
# type-filter row no longer render here -- `Header::IndexBar` moved
# to `Views::Layouts::Application` (above `:page_flash`, below
# `SearchNav`), and the type-filter row renders inline with the
# pager via `IndexPaginationNav`'s `:type_filters` slot (see
# `Views::FullPageBase::IndexNav#add_type_filters`).
module Views::Layouts
  class Header < Views::Base
    def view_template
      header(id: "header") do
        render_project_banner
        render(PageTitle.new) if controller.action_name != "index"
        render_filter_row
      end
    end

    private

    def render_project_banner
      banner = content_for(:project_banner)
      trusted_html(banner) if banner.present?
    end

    # Matches the ERB's structure: the outer `.row` is always
    # rendered, even when the inner content_for isn't set. Keeps the
    # empty row in case any CSS / JS keys off `header > .row:last-child`.
    def render_filter_row
      Row do
        render_observation_buttons if content_for?(:observation_buttons)
      end
    end

    def render_observation_buttons
      div(class: title_cols, id: "observation_buttons") do
        trusted_html(content_for(:observation_buttons))
      end
    end

    # Faithfully reproduces the ERB's quirky chain:
    # `content_for?(:left_columns) || "col-sm-8 col-lg-7"` — the `||`
    # there is operating on a boolean, so when `:left_columns` IS set
    # the LHS is `true` and `cols` becomes the literal `true`. Then
    # `class_names(Components::Column.classes_for(xs: 12), true)`
    # evaluates to `"col-12"`. Keep the bug for visual parity; fix
    # in a separate PR if needed.
    def title_cols
      cols = content_for?(:left_columns) || "col-sm-8 col-lg-7"
      cols = "" unless content_for?(:interest_icons)
      class_names(Components::Column.classes_for(xs: 12), cols)
    end
  end
end
