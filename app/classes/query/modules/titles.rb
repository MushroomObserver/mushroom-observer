module Query
  module Modules
    # Deal with titles.
    module Titles
      attr_accessor :title_tag
      attr_accessor :title_args

      def initialize_title
        @title_tag = "query_title_#{flavor}".to_sym
        @title_args = { type: model.to_s.underscore.to_sym }
      end

      def title
        initialize_query unless initialized?
        @title_tag.t(params.merge(@title_args))
      end

      # Add sort order to title of "all" queries.
      def add_sort_order_to_title
        return unless params[:by]

        self.title_tag = :query_title_all_by
        title_args[:order] = :"sort_by_#{params[:by].sub(/^reverse_/, "")}"
      end
    end
  end
end
