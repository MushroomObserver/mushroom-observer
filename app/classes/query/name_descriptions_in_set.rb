class Query::NameDescriptionInSet < Query::NameDescription
  def parameter_declarations
    super.merge(
      ids: [NameDescription]
    )
  end

  def initialize_flavor
    table = "name_descdiptions"
    set = clean_id_set(params[:ids])
    self.where << "#{table}.id IN (#{set})"
    self.order = "FIND_IN_SET(#{table}.id,'#{set}') ASC"
    super
  end
end
