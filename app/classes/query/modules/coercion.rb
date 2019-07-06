module Query
  module Modules
    # Handles coercing queries from one model to a related model.
    # 
    # Define a method in each Query subclass for each model it can be coerced
    # into.  Examples:
    #
    #   ObservationAll << ObservationBase
    #     # An index of all observations can be coerced easily into a query for
    #     # their names. Just lookup all names which have observations.
    #     def coerce_into_name_query
    #       Query.lookup(:Name, :with_observations, params)
    #     end
    #   end
    #
    #   ObservationAdvancedSearch << ObservationBase
    #     def coerce_into_name_query
    #       Query.lookup(:Name, ...)
    #     end
    #   end
    #
    module Coercion
      # Test if a query for one model can be coerced into an equivalent query
      # for a related model.
      def coercable?(new_model)
        @new_model = new_model.to_s
        return true if @new_model == model.to_s
        respond_to?(coerce_method)
      end

      # Attempt to coerce a query for one model into a related query for
      # another model.  Returns a new Query or true if successful; returns
      # +nil+ otherwise.
      def coerce(new_model)
        @new_model = new_model.to_s
        return self if @new_model == model.to_s
        return nil unless respond_to?(coerce_method)

        send(coerce_method)
      end

      def coerce_method
        "coerce_into_#{@new_model.underscore}_query"
      end

      # If coercing to blah_with_observations or blah_with_descriptions
      # queries, save current sort order in the unused parameter "old_by"
      # so we can restore it if coerced back later.  (See below.)
      def params_plus_old_by
        params2 = params.dup
        params2.delete(:by)
        add_old_by(params2)
      end

      # If returning back to observation or description query, this restores
      # the original sort order (kept silently in "old_by"). (See above.)
      def params_with_old_by_restored
        params2 = params.dup
        params2.delete(:by)
        params2.delete(:old_by)
        params2.delete(:old_title)
        params2[:by] = params[:old_by] if params.key?(:old_by)
        params2
      end

      # Save current sort order to a hash of parameters as "old_by".
      def add_old_by(hash)
        return hash unless params.key?(:by)

        hash[:old_by] = params[:by]
        hash
      end

      # Save current title to a hash of parameters as "old_title".
      def add_old_title(hash)
        hash[:old_title] = title
        hash
      end
    end
  end
end
