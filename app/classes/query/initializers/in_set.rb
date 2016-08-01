module Query::Initializers::InSet
  def initialize_in_set_flavor(table) 
    set = clean_id_set(params[:ids])
    self.where << "#{table}.id IN (#{set})"
    self.order = "FIND_IN_SET(#{table}.id,'#{set}') ASC"
  end
end
