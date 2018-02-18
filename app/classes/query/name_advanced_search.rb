module Query
  # Advanced name search.
  class NameAdvancedSearch < Query::NameBase
    include Query::Initializers::AdvancedSearch

    def parameter_declarations
      super.merge(
        advanced_search_parameter_declarations
      )
    end

    def initialize_flavor
      add_join(:observations) if params[:content].present?
      initialize_advanced_search
      super
    end

    def add_join_to_names; end

    def add_join_to_users
      add_join(:observations, :users)
    end

    def add_join_to_locations
      add_join(:observations, :locations!)
    end

    def content_join_spec
      { observations: :comments }
    end
  end
end
