module Query
  # Users in a given set.
  class UserInSet < Query::UserBase
    def parameter_declarations
      super.merge(
        ids: [User]
      )
    end

    def initialize_flavor
      initialize_in_set_flavor("users")
      super
    end
  end
end
