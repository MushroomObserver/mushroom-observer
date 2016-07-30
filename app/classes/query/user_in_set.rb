class Query::UserInSet < Query::User
  def self.parameter_declarations
    super.merge(
      ids: [User]
    )
  end

  def initialize
    set = clean_id_set(params[:ids])
    self.where << "users.id IN (#{set})"
    self.order = "FIND_IN_SET(users.id,'#{set}') ASC"
  end
end
