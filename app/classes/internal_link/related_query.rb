# frozen_string_literal: true

class InternalLink
  class RelatedQuery < InternalLink
    def initialize(query, model, html_options: {})
      @query = query
      @model = model
      super(:show_objects.t(type: model.type_tag),
            add_query_param({ controller: model.show_controller,
                              action: model.index_action }, query),
            html_options:)
    end

    private

    def html_class
      "related_#{@model.name.underscore}_query_link"
    end
  end
end
