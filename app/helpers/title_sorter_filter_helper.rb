# frozen_string_literal: true

#  add_type_filters             # add content_for(:type_filters)
#  index_sorter                 # helper to render the sorter partial
#
module TitleSorterFilterHelper
  # Conditionally dds a group of sorting links, for indexes, if relevant
  # These link back to the same index action, changing only the `by` param.
  #
  def add_sorter(query, sorts, link_all: false)
    return unless sorts && (query&.num_results&.> 1)

    content_for(:sorter) do
      links = create_sorting_links(query, sorts, link_all)

      render(partial: "application/content/sorter", locals: { links: links })
    end
  end

  # Make HTML buttons after adding relevant info to the raw sorts
  #
  # The terminology we're using to build these may be confusing:
  # `sorts` = the arrays of [by_param, :label.t] provided by index helpers.
  # `sort_links` = the same arrays, turned into [:label.t, path, id, active].
  # `links` = HTML links with all the fixin's, sent to the template
  #
  def create_sorting_links(query, sorts, link_all)
    sort_links = assemble_sort_links(query, sorts, link_all)

    sort_links.map do |title, path, identifier, active|
      classes = "btn btn-default"
      classes += " active" if active
      args = { class: class_names(classes, identifier) }
      args = args.merge(disabled: true) if active

      link_with_query(title, path, **args)
    end
  end

  # Add some info to the raw sorts: path, identifier, and if is current sort_by
  def assemble_sort_links(query, sorts, link_all)
    this_by = (query.params[:by] || query.default_order).
              to_s.sub(/^reverse_/, "")

    sort_links = sorts.map do |by, label|
      sort_link(label, query, by, this_by, link_all)
    end

    # Add a "reverse" button.
    sort_links << sort_link(:sort_by_reverse.t, query,
                            reverse_by(query, this_by), this_by, link_all)
  end

  def reverse_by(query, this_by)
    if query.params[:by].to_s.start_with?("reverse_")
      this_by
    else
      "reverse_#{this_by}"
    end
  end

  # The final product of `assemble_sort_links`: an array of attributes
  # [text, action, identifier, active]
  def sort_link(label, query, by, this_by, link_all)
    path = { controller: query.model.show_controller,
             action: query.model.index_action,
             by: by }.merge(query_params)
    identifier = "#{query.model.to_s.pluralize.underscore}_by_#{by}_link"
    active = !link_all && (by.to_s == this_by) # boolean if current sort order

    [label.t, path, identifier, active]
  end

  # type_filters, currently only used in RssLogsController#index
  def add_type_filters
    content_for(:type_filters) do
      render(partial: "application/content/type_filters")
    end
  end

  # The "Everything" tab
  def filter_for_everything(types)
    label = :rss_all.t
    link = activity_logs_path(params: { type: :all })
    help = { title: :rss_all_help.t, class: "filter-only" }
    types == ["all"] ? label : link_with_query(label, link, **help)
  end

  # A single tab
  def filter_for_type(types, type)
    label = :"rss_one_#{type}".t
    link = activity_logs_path(params: { type: type })
    help = { title: :rss_one_help.t(type: type.to_sym), class: "filter-only" }
    types == [type] ? label : link_with_query(label, link, **help)
  end
end
