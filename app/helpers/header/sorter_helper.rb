# frozen_string_literal: true

#  add_sorter                   # helper to render the sorter partial
#
module Header
  module SorterHelper
    # Conditionally adds a group of sorting links, for indexes, if relevant
    # These link back to the same index action, changing only the `by` param.
    # Called in the view, defines `:sorter` content which is rendered in layout.
    #
    def add_sorter(query, sorts, link_all: false)
      return unless sorts && (query&.num_results&.> 1)

      links = create_sorting_links(query, sorts, link_all)
      title = sort_nav_order_by(query, sorts)

      content_for(:sorter) do
        tag.div(class: "d-inline-block", id: "sorter") do
          concat(tag.label("#{:sort_by_header.l}:",
                           class: "font-weight-normal mr-2 hidden-xs"))
          concat(sort_nav_dropdown(title:, id: "sorts", links:))
        end
      end
    end

    # Make dropdown links after adding relevant info to the raw sorts
    #
    # The terminology we're using to build these may be confusing:
    # `sorts` = the arrays of [by_param, :label.t] provided by index helpers.
    # `sort_links` = the same arrays, turned into [:label.t, path, id, active].
    # `links` = HTML links with all the fixin's, sent to the template
    #
    def create_sorting_links(query, sorts, link_all)
      sort_links = assemble_sort_links(query, sorts, link_all)
      sort_links.map do |title, path_args, identifier, active|
        classes = [identifier] # "btn", "btn-default"
        classes << "active" if active
        link_by = path_args[:by]
        # Don't need to swap current dropdown title on click, so no action
        args = {
          class: class_names(classes),
          data: { by: link_by }
        }
        args = args.merge(disabled: true) if active

        link_with_query(title, path_args, **args)
      end
    end

    # Add some info to the raw sorts: path, identifier, and if is current sort_by
    def assemble_sort_links(query, sorts, link_all)
      this_by = (query.params[:order_by] || query.default_order).
                to_s.sub(/^reverse_/, "")

      sort_links = sorts.map do |by, label|
        sort_link(label, by, this_by, link_all)
      end

      # Add a "reverse" button.
      sort_links << sort_link(:sort_by_reverse.t,
                              reverse_by(query, this_by), this_by, link_all)
    end

    def reverse_by(query, this_by)
      if query.params[:order_by].to_s.start_with?("reverse_")
        this_by
      else
        "reverse_#{this_by}"
      end
    end

    # The final product of `assemble_sort_links`: an array of attributes
    # [text, action, identifier, active]
    # label arg is a translation string
    def sort_link(label, by, this_by, link_all)
      model = controller.controller_model_name
      ctlr = controller.controller_name
      helper_name = sort_link_helper_name(model, ctlr)
      # path = send(:"#{helper_name}_path", q: get_query_param)
      path = { controller: ctlr,
               action: :index,
               by: by }.merge(query_params)
      # identifier = "#{query.model.to_s.pluralize.underscore}_by_#{by}_link"
      identifier = "#{helper_name}_by_#{by}_link"
      active = !link_all && (by.to_s == this_by) # boolean if current sort order

      [label.t, path, identifier, active]
    end

    # Most controllers should have controller_model_name defined
    def sort_link_helper_name(model, ctlr)
      return ctlr unless model && ctlr != "contributors"

      model.underscore.pluralize
    end

    def sort_nav_dropdown(title: "", id: "", links: [])
      tag.div(class: "dropdown d-inline-block") do
        [
          sort_nav_toggle(title),
          tag.ul(
            id:, class: "dropdown-menu",
            aria: { labelledby: "sort_nav_toggle" }
          ) do
            links.compact.each do |link|
              concat(tag.li(link))
            end
          end
        ].safe_join
      end
    end

    def sort_nav_toggle(title)
      toggle_classes = class_names(
        %w[btn btn-sm btn-outline-default dropdown-toggle font-weight-normal]
      )
      tag.button(
        class: toggle_classes,
        id: "sort_nav_toggle", type: "button",
        data: { toggle: "dropdown" },
        aria: { haspopup: "true", expanded: "false" }
      ) do
        concat(tag.span(title))
        concat(tag.span(class: "caret ml-2"))
      end
    end

    def sort_nav_order_by(query, sorts)
      return unless query

      current_sort = query&.params&.dig(:order_by) || query.default_order.to_s
      if current_sort.start_with?("reverse_")
        current_sort = current_sort.gsub("reverse_", "")
      end
      sorts.to_h[current_sort] if sorts.to_h.key?(current_sort)
    end
  end
end
