# frozen_string_literal: true

# Gather details for items in matrix-style ndex pages.
class MatrixBoxPresenter < BasePresenter
  attr_accessor \
    :image_data, # thumbnail image tag
    :detail,     # string with extra details
    :when,       # when object or target was created
    :who,        # owner of object or target
    :what,       # link to object or target
    :where,      # location of object or target
    :time        # when object or target was last modified

  def initialize(object, view)
    super

    case object
    when Image
      image_to_presenter(object)
    when Observation
      observation_to_presenter(object)
    when RssLog
      rss_log_to_presenter(object)
    when User
      user_to_presenter(object)
    end
  end

  # Grabs all the information needed for view from RssLog instance.
  def rss_log_to_presenter(rss_log)
    target = rss_log.target
    name = target ? target.unique_format_name.t : rss_log.unique_format_name.t
    self.when = target.when&.web_date if target.respond_to?(:when)
    self.who  = h.user_link(target.user) if target&.user
    self.what =
      if target
        h.link_with_query(name, target.show_link_args)
      else
        h.link_with_query(name, rss_log.show_link_args)
      end
    self.where = h.location_link(target.place_name, target.location) \
                 if target&.respond_to?(:location)
    self.time = rss_log.updated_at

    if target&.respond_to?(:thumb_image) && target&.thumb_image
      self.image_data = {
        image: target.thumb_image,
        image_link: target.show_link_args,
        obs_data: obs_data_hash(target)
      }
    end
    return unless (temp = rss_log.detail)

    temp = target.source_credit.tpl if target.respond_to?(:source_credit) &&
                                       target.source_noteworthy?

    # To avoid calling rss_log.detail twice
    self.detail = temp
  end

  # Grabs all the information needed for view from Image instance.
  def image_to_presenter(image)
    name = image.unique_format_name.t
    self.when = begin
                  image.when.web_date
                rescue StandardError
                  nil
                end
    self.who  = h.user_link(image.user)
    self.what = h.link_with_query(name, image.show_link_args)
    self.image_data = {
      image: image,
      image_link: image.show_link_args
    }
  end

  # Grabs all the information needed for view from Observation instance.
  def observation_to_presenter(observation)
    name = observation.unique_format_name.t
    self.when  = observation.when.web_date
    self.who   = h.user_link(observation.user) if observation.user
    self.what  = h.link_with_query(name, observation.show_link_args)
    self.where = h.location_link(observation.place_name,
                                 observation.location)
    if observation.rss_log
      self.detail = observation.rss_log.detail
      self.time = observation.rss_log.updated_at
    end
    return unless observation.thumb_image

    # link_type allows an obs box to link to show_obs, or something else
    # thumbnail_helper uses identify to maybe add a "propose a name" link
    self.image_data = {
      image: observation.thumb_image,
      image_link: obs_or_other_link(observation),
      obs_data: obs_data_hash(observation)
    }
  end

  # Grabs all the information needed for view from User instance.
  def user_to_presenter(user)
    name = user.unique_text_name
    # rubocop:disable Rails/OutputSafety
    # The results of .t and web_date are guaranteed to be safe, and both
    # user.contribution and observations.count are just numbers.
    self.detail = "#{:list_users_joined.t}: #{user.created_at.web_date}<br/>
                   #{:list_users_contribution.t}: #{user.contribution}<br/>
                   #{:Observations.t}: #{user.observations.count}".html_safe
    # rubocop:enable Rails/OutputSafety
    self.what  = h.link_with_query(name, user.show_link_args)
    self.where = h.location_link(nil, user.location) if user.location
    return unless user.image_id

    self.image_data = {
      image: user.image_id,
      image_link: user.show_link_args,
      votes: false
    }
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
