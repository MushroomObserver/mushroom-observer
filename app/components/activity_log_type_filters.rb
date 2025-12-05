# frozen_string_literal: true

# Phlex component for activity logs type filter form.
# Renders checkbox buttons for filtering RssLog by type.
#
# @example Usage in helper
#   render(Components::ActivityLogTypeFilters.new(query:, types:))
#
class Components::ActivityLogTypeFilters < Components::Base
  register_value_helper :q_param

  prop :query, _Nilable(Query)
  prop :types, _Array(String)

  def view_template
    form(action: activity_logs_path, method: :get,
         class: "filter-form", id: "log_filter_form") do
      render_hidden_fields
      render_filter_buttons
    end
  end

  private

  def render_hidden_fields
    return unless @query

    query_params_except_type.each do |key, value|
      input(type: "hidden", name: key, value: value)
    end
  end

  def render_filter_buttons
    div(class: "btn-group pb-1 hidden-xs text-nowrap") do
      render_show_label
      render_everything_button
      render_type_buttons
      render_submit_button
    end
  end

  def render_show_label
    span(class: "btn btn-default btn-sm disabled") { :rss_show.t }
  end

  def render_everything_button
    span(class: everything_button_classes) do
      filter_for_everything
    end
  end

  def render_type_buttons
    RssLog::ALL_TYPE_TAGS.map(&:to_s).each do |type|
      render_type_checkbox(type)
    end
  end

  def render_submit_button
    input(type: "submit", value: :SUBMIT.t, class: "btn btn-default btn-sm")
  end

  # Individual type checkbox styled as button
  def render_type_checkbox(type)
    label(class: type_button_classes(type)) do
      input(type: "checkbox", name: "q[type][]", value: type,
            checked: type_checked?(type), id: "type_#{type}",
            class: "mt-0 mr-2")
      filter_for_type(type)
    end
  end

  # "Everything" filter - returns label or link
  def filter_for_everything
    label_text = :rss_all.t
    return plain(label_text) if @types == ["all"]

    link = activity_logs_path(q: query_params_with_type("all"))
    a(href: link, title: :rss_all_help.t, class: "filter-only") { label_text }
  end

  # Individual type filter - returns label or link
  def filter_for_type(type)
    label_text = :"rss_one_#{type}".t
    return plain(label_text) if @types == [type]

    link = activity_logs_path(q: query_params_with_type(type))
    a(href: link,
      title: :rss_one_help.t(type: type.to_sym),
      class: "filter-only") { label_text }
  end

  # CSS class helpers

  def everything_button_classes
    class_names("btn btn-default btn-sm", { active: @types == ["all"] })
  end

  def type_button_classes(type)
    class_names(
      "btn btn-default btn-sm filter-checkbox my-0",
      { active: @types == [type] }
    )
  end

  # Query param helpers

  def type_checked?(type)
    @types.include?(type) || @types == ["all"]
  end

  def query_params_except_type
    return {} unless @query

    q = q_param(@query).except(:type)
    # Convert { q: { model: "RssLog" } }.to_query to key/value pairs
    query_string = { q: q }.to_query
    pairs = query_string.split("&")
    pairs.to_h do |pair|
      key, value = pair.split("=", 2).map { |str| CGI.unescape(str) }
      [key, value]
    end
  end

  def query_params_with_type(type)
    return { type: type } unless @query

    q_param(@query).merge(type: type)
  end
end
