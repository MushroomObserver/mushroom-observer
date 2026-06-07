# frozen_string_literal: true

# The header block immediately below the application top nav. Rendered
# once per page by the application layout. Composes (in order):
#
#   - the optional `:project_banner` content_for slot;
#   - on non-index actions, the page title strip
#     (`Header::PageTitle` — replaces `_page_title.erb`);
#   - on index actions (and `maps` show), the index filter / pager
#     bar (still ERB: `_index_bar.erb`);
#   - the rss-log type-filter row and project observation-buttons
#     row, both fed from content_for slots.
#
# `any_content_filters_applied` is the controller-set ivar that
# `ApplicationController::Indexes` populates on index actions; we
# accept it explicitly (the layout passes it) rather than poking
# `controller.instance_variable_get`. Nil for non-index actions.
module Views::Controllers::Application::Content
  class Header < Views::Base
    prop :any_content_filters_applied, _Nilable(_Boolean), default: nil

    def view_template
      maybe_set_filter_help

      header(id: "header") do
        render_project_banner
        render(PageTitle.new) if controller.action_name != "index"
        render(IndexBar.new) if index_bar?
        render_filter_row
      end
    end

    private

    # Inlined from `Header::FiltersHelper#add_filter_help` — the only
    # caller was `_header.html.erb`, and Phlex needs the call to live
    # in a context that can `content_for`. The helper version stays
    # in place for now; this method overshadows its single use here.
    def maybe_set_filter_help
      return unless @any_content_filters_applied

      content_for(:filter_help) do
        render(Components::HelpTooltip.new(
                 label: "(#{:filtered.t})",
                 title: :rss_filtered_mouseover.t,
                 extra_class: "filter-help"
               ))
      end
    end

    def render_project_banner
      banner = content_for(:project_banner)
      trusted_html(banner) if banner.present?
    end

    def index_bar?
      action = controller.action_name
      controller_name = controller.controller_name
      (action == "index" && controller_name != "articles") ||
        controller_name == "maps"
    end

    # Matches the ERB exactly: the outer `.row` is always rendered,
    # even when neither inner content_for is set. Keeps the empty
    # row in case any CSS / JS keys off `header > .row:last-child`.
    def render_filter_row
      div(class: "row") do
        render_type_filters if content_for?(:type_filters)
        render_observation_buttons if content_for?(:observation_buttons)
      end
    end

    def render_type_filters
      div(class: "hidden-print col-xs-12") do
        trusted_html(content_for(:type_filters))
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
    # `class_names("col-xs-12", true)` evaluates to `"col-xs-12"`.
    # Keep the bug for visual parity; fix in a separate PR if needed.
    def title_cols
      cols = content_for?(:left_columns) || "col-sm-8 col-lg-7"
      cols = "" unless content_for?(:interest_icons)
      class_names("col-xs-12", cols)
    end
  end
end
