class Query::ImageInsideObservation < Query::ImageBase
  def parameter_declarations
    super.merge(
      observation: Observation,
      outer:       :query
    )
  end

  def initialize_flavor
    obs = find_cached_parameter_instance(Observation, :observation)
    title_args[:observation] = obs.unique_format_name

    ids = []
    ids << obs.thumb_image_id if obs.thumb_image_id
    ids += obs.image_ids - [obs.thumb_image_id]
    set = clean_id_set(ids)
    self.where << "images.id IN (#{set})"
    self.order = "FIND_IN_SET(images.id,'#{set}') ASC"

    self.outer_id = params[:outer]

    # Tell outer query to skip observations with no images!
    self.tweak_outer_query = lambda do |outer|
      extend_where(outer.params) << "observations.thumb_image_id IS NOT NULL"
    end

    super
  end
end
