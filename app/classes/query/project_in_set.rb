class Query::ProjectInSet < Query::Project
  def parameter_declarations
    super.merge(
      ids: [Project]
    )
  end

  def initialize_flavor
    table = "projects"
    set = clean_id_set(params[:ids])
    self.where << "#{table}.id IN (#{set})"
    self.order = "FIND_IN_SET(#{table}.id,'#{set}') ASC"
    super
  end
end
