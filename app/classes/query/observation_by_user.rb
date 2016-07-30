class Query::ObservationByUser < Query::Observation
  def self.parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    self.where << "observations.user_id = '#{user.id}'"
    params[:by] ||= "updated_at"
  end
end
