# frozen_string_literal: true

# The header block below the top nav: project banner, non-index
# page-title strip, and the observation-buttons row. `Header::IndexBar`
# moved to `Views::Layouts::Application`; the type-filter row renders
# via `IndexPaginationNav`'s `:type_filters` slot (see
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

    # Matches the title row's left-column width to the content row's.
    # `cols` is the boolean `content_for?(:left_columns)` when that
    # slot is set (not its value), and `class_names(..., true)`
    # resolves to `"col-12"` -- full width, same as the content row.
    def title_cols
      cols = content_for?(:left_columns) || "col-sm-8 col-lg-7"
      cols = "" unless content_for?(:interest_icons)
      class_names(Components::Column.classes_for(xs: 12), cols)
    end
  end
end
