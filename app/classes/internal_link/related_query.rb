# frozen_string_literal: true

class InternalLink
  class RelatedQuery < InternalLink
    def initialize(query, model, controller, html_options: {})
      @query = query
      @model = model
      super(:show_objects.t(type: model.type_tag),
            controller.add_query_param({ controller: model.show_controller,
                                         action: model.index_action }, query),
            html_options:)
    end

    private

    def html_class
      "related_#{@model.name.underscore.pluralize}_link"
    end
  end
end
