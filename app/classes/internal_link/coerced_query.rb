# frozen_string_literal: true

class InternalLink
  class CoercedQuery < InternalLink
    def initialize(query, model, html_options: {})
      @query = query
      @model = model
      super(:show_objects.t(type: model.type_tag),
            { controller: model.show_controller,
              action: model.index_action,
              q: query.id.alphabetize },
            html_options:)
    end

    private

    def html_class
      "coerced_#{@model.name.underscore}_query_link"
    end
  end
end
