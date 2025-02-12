# frozen_string_literal: true

class InternalLink
  # Consider a page like "Locations in Augusta County, Virginia, USA".
  # The page may have "related links" like "Observations at these Locations"
  # and "Names at these Locations". This class generates those filtered links.
  #
  # For the link "Observations [model] at these Locations [type]", the `model`
  # is the index you're linking to. The `type` is the filtering subquery, which
  # is usually the `current_query` on the page you're linking from.
  #
  class RelatedQuery < InternalLink
    def initialize(model, type, current_query, controller, html_options: {})
      @model = model.name.to_sym
      @type = type
      @current_query = current_query
      @title = :show_objects.t(type: model.type_tag)
      query = current_or_related_objects_query
      @url = controller.add_query_param({ controller: model.show_controller,
                                          action: model.index_action }, query)

      super(@title, @url, html_options:)
    end

    private

    # "Related" links are made by `current_or_related_objects_query` and may be:
    # (1) From maps to indexes of the same objects, reusing the current_query.
    # (2) Links from an index that itself was the result of a subquery.
    #     If you follow links in the UI from:
    #       Observations of these names -> (obs query)
    #       Locations of these observations -> (loc, obs_subquery)
    #       Map of these locations -> (loc, obs_subquery)
    #       Names at these locations -> (name, obs_subquery)
    #       Observations of these names -> (obs query)
    #     Note that the last index is really the original query, so to prevent
    #     recursive subquery nesting, we always want check for the currently
    #     needed (sub)query nested within the params.
    # (3) A new query for the related model, using the current query as the
    #     subquery.
    #
    # Passing `controller` allows access to `add_query_param` for adding
    # the dynamic query param made by `current_or_related_objects_query`.
    # We're considering these subqueries provisional...they're not trying to
    # become the current query.
    #
    def current_or_related_objects_query
      if @model == @type
        @current_query
      elsif restored_query
        restored_query
      elsif new_query
        new_query
      # else
      #   raise("Related object query should not be blank: " \
      #         "model: #{@model} type: #{@type} " \
      #         "current_query: #{@current_query.params.inspect}")
      end
    end

    # Check the query params hash for a relevant existing query nested within.
    def restored_query
      subquery_param = @current_query.class.find_subquery_param_name(@model)
      restorable_query = @current_query.params.deep_find(subquery_param)
      return false if restorable_query.blank?

      Query.lookup(@model, **restorable_query)
    end

    # Make a new query using the current_query as the subquery. Note that this
    # will continue nesting queries unless a restorable query is found above.
    def new_query
      query_class = "Query::#{@model.to_s.pluralize}".constantize
      return unless (subquery = query_class.find_subquery_param_name(@type)) &&
                    @current_query.params.compact.present?

      Query.lookup(@model, "#{subquery}": @current_query.params)
    end

    def html_class
      "related_#{@model.name.underscore.pluralize}_link"
    end
  end
end
