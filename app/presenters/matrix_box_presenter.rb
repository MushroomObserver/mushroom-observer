# frozen_string_literal: true

# Gather details for items in matrix-style index pages.
class MatrixBoxPresenter < BasePresenter
  attr_accessor \
    :id,         # id of the target or log object
    :type,       # what kind of box is this
    :image_data, # data passed to thumbnail_presenter
    :when,       # when object or target was created
    :who,        # owner of object or target
    :name,       # name of object or target
    :what,       # link to object or target
    :consensus,  # object for determining the current favorite name of an obs
    :where,      # place name of location
    :location,   # location (object) of object or target
    :detail,     # string with extra details
    :time        # when object or target was last modified

  def initialize(_user, object)
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
    if target.respond_to?(:location)
      self.where = target.where
      self.location = target.location
    end
    self.time = rss_log.updated_at

    figure_out_rss_log_target_images(target)
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
      # for matrix_box_carousels:
      # images: [image],
      image_link: image.show_link_args,
      full_width: true
    }
  end

  # Grabs all the information needed for view from Observation instance.
  def observation_to_presenter(observation)
    self.id         = observation.id
    self.type       = :observation
    self.when       = observation.when.web_date
    self.who        = observation.user if observation.user
    self.name       = observation.user_format_name(observation.user).
                      t.break_name.small_author
    self.what       = observation
    self.where      = observation.where
    self.location   = observation.location
    self.consensus  = Observation::NamingConsensus.new(observation)
    if observation.rss_log
      self.detail = observation.rss_log.detail
      self.time = observation.rss_log.updated_at
    end
    return unless observation.thumb_image_id

    # for matrix_box_carousels:
    # observation.images is eager-loaded, observation.thumb_image is not.
    # thumb_image = observation.images.
    #               find { |i| i.id == observation.thumb_image_id }

    self.image_data = {
      image: observation.thumb_image,
      # for matrix_box_carousels:
      # images: observation.images,
      # thumb_image: thumb_image,
      image_link: observation.show_link_args, # false for thumb thru images
      obs: observation,
      full_width: true
    }
  end

  # Grabs all the information needed for view from User instance.
  def user_to_presenter(user)
    self.id = user.id
    self.type = :user
    self.detail = user
    self.name = user.unique_text_name
    self.what = user
    self.where = user.location.name if user.location
    self.location = user.location if user.location
    return unless user.image_id

    # Not user.images because that's every image they've uploaded
    self.image_data = {
      image: user.image,
      # for matrix_box_carousels:
      # images: [user.image_id],
      image_link: user.show_link_args,
      votes: false,
      full_width: true
    }
  end

  # The target may not have images or a thumb_image
  def figure_out_rss_log_target_images(target)
    return unless target.respond_to?(:thumb_image) && target&.thumb_image

    # for matrix_box_carousels replace the above line with:
    # images = if target.respond_to?(:images) &&
    #            target&.images&.length&.positive?
    #            target.images
    #          elsif target.respond_to?(:thumb_image) && target&.thumb_image
    #            [target.thumb_image]
    #          end
    # return unless images

    self.image_data = {
      image: target.thumb_image,
      image_link: target.show_link_args,
      # for matrix_box_carousels:
      # images: images,
      # image_link: target.show_link_args,
      obs: obs_data(target),
      full_width: true
    }
  end

  def display_time
    time&.display_time
  end

  # pass another arg to allow image stretched-link to link to obs, or other obj
  def obs_or_other_link(observation)
    observation.show_link_args
  end

  # 20231125 Switched from a hash of { id:, obs: } to just obs
  def obs_data(observation)
    return {} unless observation.respond_to?(:is_collection_location)

    observation
  end
end
