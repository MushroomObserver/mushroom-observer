class Query::ImageInSet < Query::Image
  def parameter_declarations
    super.merge(
      ids: [Image]
    )
  end

  def initialize_flavor
    set = clean_id_set(params[:ids])
    self.where << "images.id IN (#{set})"
    self.order = "FIND_IN_SET(images.id,'#{set}') ASC"
    super
  end
end
