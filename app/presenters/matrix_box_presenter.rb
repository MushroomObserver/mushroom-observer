# frozen_string_literal: true

# Gather details for items in matrix-style ndex pages.
class MatrixBoxPresenter
  attr_accessor \
    :thumbnail, # thumbnail image tag
    :detail,    # string with extra details
    :when,      # when object or target was created
    :who,       # owner of object or target
    :what,      # link to object or target
    :where,     # location of object or target
    :time       # when object or target was last modified

  def initialize(object, view, link_type = :target, link_method = :get,
                 identify = nil)
    case object
    when Image
      image_to_presenter(object, view)
    when Observation
      observation_to_presenter(object, view, link_type, link_method, identify)
    when RssLog
      rss_log_to_presenter(object, view)
    when User
      user_to_presenter(object, view)
    end
  end

  # Grabs all the information needed for view from RssLog instance.
  def rss_log_to_presenter(rss_log, view)
    target = rss_log.target
    name = target ? target.unique_format_name.t : rss_log.unique_format_name.t
    self.when = target.when&.web_date if target.respond_to?(:when)
    self.who  = view.user_link(target.user) if target&.user
    self.what =
      if target
        view.link_with_query(name, target.show_link_args)
      else
        view.link_with_query(name, rss_log.show_link_args)
      end
    self.where = view.location_link(target.place_name, target.location) \
                 if target&.respond_to?(:location)
    self.time = rss_log.updated_at

    self.thumbnail =
      if target&.respond_to?(:thumb_image) && target&.thumb_image
        view.thumbnail(target.thumb_image,
                       link: target.show_link_args,
                       obs_data: obs_data_hash(target))
      end
    return unless (temp = rss_log.detail)

    temp = target.source_credit.tpl if target.respond_to?(:source_credit) &&
                                       target.source_noteworthy?

    # To avoid calling rss_log.detail twice
    self.detail = temp
  end

  # Grabs all the information needed for view from Image instance.
  def image_to_presenter(image, view)
    name = image.unique_format_name.t
    self.when = begin
                  image.when.web_date
                rescue StandardError
                  nil
                end
    self.who  = view.user_link(image.user)
    self.what = view.link_with_query(name, image.show_link_args)
    self.thumbnail = view.thumbnail(image, link: image.show_link_args)
  end

  # Grabs all the information needed for view from Observation instance.
  def observation_to_presenter(observation, view, link_type, link_method,
                               identify)
    name = observation.unique_format_name.t
    self.when  = observation.when.web_date
    self.who   = view.user_link(observation.user) if observation.user
    self.what  = view.link_with_query(name, observation.show_link_args)
    self.where = view.location_link(observation.place_name,
                                    observation.location)
    if observation.rss_log
      self.detail = observation.rss_log.detail
      self.time = observation.rss_log.updated_at
    end
    return unless observation.thumb_image

    # link_type allows an obs box to link to show_obs, or something else
    # thumbnail_helper uses identify to maybe add a "propose a name" link
    self.thumbnail =
      view.thumbnail(observation.thumb_image,
                     link: obs_or_other_link(observation),
                     link_type: link_type, link_method: link_method,
                     identify: identify, obs_data: obs_data_hash(observation))
  end

  # Grabs all the information needed for view from User instance.
  def user_to_presenter(user, view)
    name = user.unique_text_name
    # rubocop:disable Rails/OutputSafety
    # The results of .t and web_date are guaranteed to be safe, and both
    # user.contribution and observations.count are just numbers.
    self.detail = "#{:list_users_joined.t}: #{user.created_at.web_date}<br/>
                   #{:list_users_contribution.t}: #{user.contribution}<br/>
                   #{:Observations.t}: #{user.observations.count}".html_safe
    # rubocop:enable Rails/OutputSafety
    self.what  = view.link_with_query(name, user.show_link_args)
    self.where = view.location_link(nil, user.location) if user.location
    return unless user.image_id

    self.thumbnail =
      view.thumbnail(user.image_id, link: user.show_link_args, votes: false)
  end

  def fancy_time
    time&.fancy_time
  end

  def obs_or_other_link(observation)
    observation.show_link_args
  end

  def obs_data_hash(observation)
    return {} unless observation&.respond_to?(:is_collection_location)

    { id: observation.id, obs: observation }
  end
end
