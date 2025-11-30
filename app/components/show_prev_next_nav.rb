# frozen_string_literal: true

# Prev/Index/Next navigation for show pages.
# Displays when viewing an object in the context of a query.
class Components::ShowPrevNextNav < Components::Base
  BTN_CLASSES = %w[navbar-link navbar-left btn btn-lg px-0].freeze

  prop :object, _Any
  prop :query, _Nilable(_Any)

  def view_template
    return unless @object && @query

    ul(class: "nav navbar-flex object_pager") do
      li { render_adjacent_link(:prev) }
      li { render_index_link }
      li { render_adjacent_link(:next) }
    end
  end

  private

  def render_adjacent_link(dir)
    hide = no_more?(dir) ? "disabled opacity-0" : ""
    classes = class_names(BTN_CLASSES, "#{dir}_object_link", hide)
    adjacent_id = @query.send(:"#{dir}_id")
    href = adjacent_id ? adjacent_path(adjacent_id) : "#"
    title = adjacent_title(dir)

    a(href: href, class: class_names("icon-link", classes), title: title,
      data: { toggle: "tooltip", title: title }) do
      link_icon(dir, class: "px-2")
      span(class: "sr-only") { title }
    end
  end

  def render_index_link
    classes = class_names(BTN_CLASSES, %w[mx-1 index_object_link])
    icon = index_icon
    href = index_path
    title = index_title

    a(href: href, class: class_names("icon-link", classes), title: title,
      data: { toggle: "tooltip", title: title }) do
      link_icon(icon, class: "px-2")
      span(class: "sr-only") { title }
    end
  end

  def no_more?(dir)
    if dir == :prev
      @query.result_ids.first == @object.id
    else
      @query.result_ids.last == @object.id
    end
  end

  def adjacent_path(id)
    return activity_log_path(id: id) if type_tag == :rss_log

    send(:"#{type_tag}_path", id: id)
  end

  def adjacent_title(dir)
    :"#{dir.upcase}_OBJECT".t(type: type_name)
  end

  def index_path
    args = add_q_param(@object.index_link_args, @query)
    url_for(args.merge(only_path: true))
  end

  def index_title
    :INDEX_OBJECT.t(type: type_name.pluralize)
  end

  def index_icon
    type_tag == :observation ? :grid : :list
  end

  def type_tag
    @type_tag ||= @object.type_tag
  end

  def type_name
    @type_name ||= :"#{type_tag.upcase}".l
  end
end
