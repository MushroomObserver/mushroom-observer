# frozen_string_literal: true

class CoercedQueryTab
  def initialize(query, model, html_options: {})
    @query = query
    @model = model
    @html_options = html_options
    @html_options[:class] = html_class unless @html_options.include?(:class)
  end

  def tab
    [:show_objects.t(type: @model.type_tag),
     { controller: @model.show_controller,
       action: @model.index_action,
       q: @query.id.alphabetize },
     @html_options]
  end

  private

  def html_class
    "coerced_#{@model.name.underscore}_query_link"
  end
end
