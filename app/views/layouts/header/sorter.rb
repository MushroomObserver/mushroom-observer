# frozen_string_literal: true

# Index-page sort-bar. Two list items in a horizontal nav:
# `<ul class="navbar-flex pl-3 sorter">` with a `<li>` `Sort by:`
# label + a `<li>` `Components::Dropdown` whose menu lists every
# available sort option plus a `Reverse` entry. Stashed in
# `content_for(:sorter)` by `add_sorter` in the index view.
#
# `sorts` is `[[order_by_key, label_translation_symbol], ...]`, the
# shape every `<Foo>Controller#index_sort_options` returns.
#
# `link_all: true` skips the "currently active, render as disabled"
# behavior so every option (including the current one) is a live
# link — used where the sort is set by URL params rather than by
# the page's current query state.
module Views::Layouts
  class Header::Sorter < Views::Base
    prop :query, _Nilable(::Query), default: nil
    prop :sorts,
         _Nilable(_Array(_Array(_Union(::String, ::Symbol)))),
         default: nil
    prop :link_all, _Boolean, default: false

    def view_template
      return unless visible?

      ul(class: "list-unstyled navbar-flex pl-3 sorter") do
        li(class: "navbar-text mx-0 hidden-xs") do
          plain("#{:sort_by_header.l}:")
        end
        Dropdown(
          id: "sort_nav_toggle",
          menu_id: "sort_nav_menu",
          label: toggle_title.to_s,
          wrapper_class: "navbar-form px-2",
          toggle_variant: :outline, toggle_size: :sm,
          toggle_class: "font-weight-normal",
          menu_class: "sorts",
          menu_header: mobile_header_html
        ) do |menu|
          menu.section(sort_tuples)
        end
      end
    end

    private

    def visible?
      @sorts.present? && (@query&.num_results&.> 1)
    end

    def toggle_title
      current = (@query&.params&.dig(:order_by) ||
                 @query&.default_order.to_s).to_s.sub(/^reverse_/, "")
      @sorts.to_h[current] if @sorts.to_h.key?(current)
    end

    # The mobile-only `Sort by:` header that sits at the top of the
    # dropdown menu on extra-small viewports. Pre-captured to a
    # SafeBuffer so `Components::Dropdown` can splat it into its
    # `<ul>` via `trusted_html`.
    def mobile_header_html
      capture do
        li(class: "visible-xs") do
          a(href: "#", disabled: true, class: "opacity-75") do
            plain("#{:sort_by_header.l}:")
          end
        end
      end
    end

    # `[text, url, args]` tuples for the dropdown menu — one per
    # sort option plus the trailing `Reverse` entry. `args[:active]`
    # marks the current sort so `Components::Dropdown#render_link`
    # paints it `.active` and disables the link.
    def sort_tuples
      this_by = (@query.params[:order_by] || @query.default_order).
                to_s.sub(/^reverse_/, "")
      tuples = @sorts.map { |by, label| sort_tuple(label, by, this_by) }
      tuples << sort_tuple(:sort_by_reverse.t,
                           reverse_by(this_by), this_by)
    end

    def reverse_by(this_by)
      if @query.params[:order_by].to_s.start_with?("reverse_")
        this_by
      else
        "reverse_#{this_by}"
      end
    end

    def sort_tuple(label, by, this_by)
      path = { controller: controller_name, action: action_name,
               q: q_param(@query).merge(order_by: by) }
      identifier = "#{sort_link_helper_name}_by_#{by}_link"
      active = !@link_all && (by.to_s == this_by)
      [label.t, path, { class: identifier, data: { by: by }, active: active }]
    end

    def sort_link_helper_name
      model = controller.controller_model_name
      ctlr = controller_name
      return ctlr unless model && ctlr != "contributors"

      model.underscore.pluralize
    end
  end
end
