# frozen_string_literal: true

class InternalLink
  # A filtered index like "Locations in Augusta County, Virginia, USA" may offer
  # "related links" like "Observations at these Locations" and
  # "Names at these Locations". This class generates those filtered links
  # using `Query.current_or_related_query`.
  #
  # For the link "Observations [model] at these Locations [filter]", the `model`
  # is the index you're linking to. The `filter` is the filtering subquery,
  # which is usually the `current_query` on the page you're linking from.
  #
  class RelatedQuery < InternalLink
    def initialize(model, filter, current_query, controller, html_options: {})
      @model = model
      target = model.name.to_sym
      @title = :show_objects.t(type: model.type_tag)
      query = Query.current_or_related_query(target, filter, current_query)
      @url = controller.add_q_param({ controller: model.show_controller,
                                      action: model.index_action }, query)

      super(@title, @url, html_options:)
    end

    private

    def html_class
      "related_#{@model.name.underscore.pluralize}_link"
    end
  end
end
