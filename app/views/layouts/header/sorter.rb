# frozen_string_literal: true

# Dropdown sort-bar for index pages. Renders a navbar with a
# `Sort by: <current>` label that opens a dropdown of every available
# sort option plus a "Reverse" entry. Mirrors the markup the legacy
# `Header::SorterHelper` produced; rendered by `add_sorter` in the
# index view (which stashes the output in `content_for(:sorter)`).
#
# `sorts` is `[[order_by_key, label_translation_symbol], ...]`, the
# same shape every `<Foo>Controller#index_sort_options` returns.
#
# `link_all: true` skips the "currently active, render as disabled
# link" behavior so every option (including the current one) is a
# live link — used in places where the sort is set by URL params
# rather than reflected in the page's current query state.
module Views::Layouts
  class Header::Sorter < Views::Base
    prop :query, _Nilable(::Query::Base), default: nil
    prop :sorts,
         _Nilable(_Array(_Array(_Union(::String, ::Symbol)))),
         default: nil
    prop :link_all, _Boolean, default: false

    def view_template
      return unless visible?

      div(class: "navbar-flex pl-3 sorter") do
        div(class: "navbar-text mx-0 hidden-xs") do
          plain("#{:sort_by_header.l}:")
        end
        render_dropdown
      end
    end

    private

    def visible?
      @sorts.present? && (@query&.num_results&.> 1)
    end

    def render_dropdown
      div(class: "dropdown d-inline-block navbar-form px-2") do
        render_toggle
        ul(class: "sorts dropdown-menu",
           aria: { labelledby: "sort_nav_toggle" }) do
          render_mobile_header
          sorting_links.compact.each { |link| li { trusted_html(link) } }
        end
      end
    end

    def render_toggle
      button(
        class: class_names(%w[btn btn-sm btn-outline-default
                              dropdown-toggle font-weight-normal]),
        id: "sort_nav_toggle", type: "button",
        data: { toggle: "dropdown" },
        aria: { haspopup: "true", expanded: "false" }
      ) do
        span { plain(toggle_title.to_s) }
        span(class: "caret ml-2")
      end
    end

    def render_mobile_header
      li(class: "visible-xs") do
        a(href: "#", disabled: true, class: "opacity-75") do
          plain("#{:sort_by_header.l}:")
        end
      end
    end

    def toggle_title
      current = (@query&.params&.dig(:order_by) ||
                 @query&.default_order.to_s).to_s.sub(/^reverse_/, "")
      @sorts.to_h[current] if @sorts.to_h.key?(current)
    end

    # The terminology mirrors the legacy helper:
    # - `sorts` = `[order_by_key, :label]` tuples from the controller
    # - `sort_link_data` = same enriched with [label, path, id, active]
    # - `sorting_links` = the final HTML link strings
    def sorting_links
      sort_link_data.map do |title, path_args, identifier, active|
        classes = [identifier]
        classes << "active" if active
        args = { class: class_names(classes),
                 data: { by: path_args[:by] } }
        args[:disabled] = true if active
        link_to(title, path_args, **args)
      end
    end

    def sort_link_data
      this_by = (@query.params[:order_by] || @query.default_order).
                to_s.sub(/^reverse_/, "")
      data = @sorts.map { |by, label| sort_link_tuple(label, by, this_by) }
      data << sort_link_tuple(:sort_by_reverse.t,
                              reverse_by(this_by), this_by)
    end

    def reverse_by(this_by)
      if @query.params[:order_by].to_s.start_with?("reverse_")
        this_by
      else
        "reverse_#{this_by}"
      end
    end

    def sort_link_tuple(label, by, this_by)
      path = { controller: controller_name, action: action_name,
               q: q_param(@query).merge(order_by: by) }
      identifier = "#{sort_link_helper_name}_by_#{by}_link"
      active = !@link_all && (by.to_s == this_by)
      [label.t, path, identifier, active]
    end

    def sort_link_helper_name
      model = controller.controller_model_name
      ctlr = controller_name
      return ctlr unless model && ctlr != "contributors"

      model.underscore.pluralize
    end
  end
end
