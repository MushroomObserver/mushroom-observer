# frozen_string_literal: true

# Gather details for items in matrix-style ndex pages.
class MatrixBoxPresenter < BasePresenter
  attr_accessor \
    :id,         # id of the target or log object
    :type,       # what kind of box is this
    :image_data, # data passed to thumbnail_presenter
    :when,       # when object or target was created
    :who,        # owner of object or target
    :name,       # name of object or target
    :what,       # link to object or target
    :place_name, # place name of location
    :where,      # location (object) of object or target
    :detail,     # string with extra details
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
    self.id = target&.id || rss_log.id
    self.type = rss_log.target_type || :rss_log
    self.when = target.when&.web_date if target.respond_to?(:when)
    self.who  = target.user if target&.user
    self.name = if rss_log.target_type == :image
                  target.unique_format_name.t
                elsif target
                  target.format_name.t.break_name.small_author
                else
                  rss_log.format_name.t.break_name.small_author
                end
    self.what = target || rss_log
    if target&.respond_to?(:location)
      self.place_name = target.place_name
      self.where = target.location
    end
    self.time = rss_log.updated_at

    if target&.respond_to?(:thumb_image) && target&.thumb_image
      self.image_data = {
        image: target.thumb_image,
        image_link: target.show_link_args,
        obs_data: obs_data_hash(target),
        context: :matrix_box
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
    self.id = image.id
    self.type = :image
    self.when = begin
                  image.when.web_date
                rescue StandardError
                  nil
                end
    self.who  = image.user
    self.name = image.unique_format_name.t
    self.what = image
    self.image_data = {
      image: image,
      image_link: image.show_link_args,
      context: :matrix_box
    }
  end

  # Grabs all the information needed for view from Observation instance.
  def observation_to_presenter(observation)
    self.id         = observation.id
    self.type       = :observation
    self.when       = observation.when.web_date
    self.who        = observation.user if observation.user
    self.name       = observation.format_name.t.break_name.small_author
    self.what       = observation
    self.place_name = observation.place_name
    self.where      = observation.location
    if observation.rss_log
      self.detail = observation.rss_log.detail
      self.time = observation.rss_log.updated_at
    end
    return unless observation.thumb_image

    self.image_data = {
      image: observation.thumb_image,
      image_link: obs_or_other_link(observation),
      obs_data: obs_data_hash(observation),
      context: :matrix_box
    }
  end

  # Grabs all the information needed for view from User instance.
  def user_to_presenter(user)
    self.id = user.id
    self.type = :user
    # rubocop:disable Rails/OutputSafety
    # The results of .t and web_date are guaranteed to be safe, and both
    # user.contribution and observations.count are just numbers.
    self.detail = "#{:list_users_joined.t}: #{user.created_at.web_date}<br/>
                   #{:list_users_contribution.t}: #{user.contribution}<br/>
                   #{:Observations.t}: #{user.observations.count}".html_safe
    # rubocop:enable Rails/OutputSafety
    self.name = user.unique_text_name
    self.what = user
    self.place_name = nil
    self.where = user.location if user.location
    return unless user.image_id

    self.image_data = {
      image: user.image_id,
      image_link: user.show_link_args,
      votes: false,
      context: :matrix_box
    }
  end

  def display_time
    time&.display_time
  end

  # pass another arg to allow image stretched-link to link to obs, or other obj
  def obs_or_other_link(observation)
    observation.show_link_args
  end

  def obs_data_hash(observation)
    return {} unless observation&.respond_to?(:is_collection_location)

    { id: observation.id, obs: observation }
  end
end
