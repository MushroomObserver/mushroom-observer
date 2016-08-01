class Query::NameInSet < Query::Name
  def parameter_declarations
    super.merge(
      ids: [Name]
    )
  end

  def initialize_flavor
    set = clean_id_set(params[:ids])
    self.where << "names.id IN (#{set})"
    self.order = "FIND_IN_SET(names.id,'#{set}') ASC"
    super
  end
end
