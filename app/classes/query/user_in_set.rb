class Query::UserInSet < Query::User
  def parameter_declarations
    super.merge(
      ids: [User]
    )
  end

  def initialize_flavor
    set = clean_id_set(params[:ids])
    self.where << "users.id IN (#{set})"
    self.order = "FIND_IN_SET(users.id,'#{set}') ASC"
    super
  end
end
