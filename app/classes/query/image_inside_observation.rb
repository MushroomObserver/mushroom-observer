class Query::ImageInsideObservation < Query::ImageBase
  def parameter_declarations
    super.merge(
      observation: Observation,
      outer: :query
    )
  end

  def initialize_flavor
    obs = find_cached_parameter_instance(Observation, :observation)
    title_args[:observation] = obs.unique_format_name
    imgs = image_set(obs)
    where << "images.id IN (#{imgs})"
    self.order = "FIND_IN_SET(images.id,'#{imgs}') ASC"
    self.outer_id = params[:outer]
    skip_observations_with_no_images
    super
  end

  def image_set(obs)
    ids = []
    ids << obs.thumb_image_id if obs.thumb_image_id
    ids += obs.image_ids - [obs.thumb_image_id]
    clean_id_set(ids)
  end

  # Tell outer query to skip observations with no images!
  def skip_observations_with_no_images
    self.tweak_outer_query = lambda do |outer|
      extend_where(outer.params) << "observations.thumb_image_id IS NOT NULL"
    end
  end
end
