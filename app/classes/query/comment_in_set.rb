module Query
  # Comments in a given set.
  class CommentInSet < Query::CommentBase
    def parameter_declarations
      super.merge(
        ids: [Comment]
      )
    end

    def initialize_flavor
      initialize_in_set_flavor("comments")
      super
    end
  end
end
