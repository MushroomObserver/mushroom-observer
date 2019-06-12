class Query::UserInSet < Query::UserBase
  def parameter_declarations
    super.merge(
      ids: [User]
    )
  end

  def initialize_flavor
    add_id_condition("users.id", params[:ids])
    super
  end
end
