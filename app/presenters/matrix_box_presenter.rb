# frozen_string_literal: true

class MatrixBoxPresenter
  attr_accessor \
    :thumbnail, # thumbnail image tag
    :detail,    # string with extra details
    :when,      # when object or target was created
    :who,       # owner of object or target
    :what,      # link to object or target
    :where,     # location of object or target
    :time       # when object or target was last modified

  def initialize(object, view)
    case object
    when Image
      image_to_presenter(object, view)
    when Observation
      observation_to_presenter(object, view)
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
        view.link_with_query(name,
                             controller: target.show_controller,
                             action: target.show_action,
                             id: target.id)
      else
        view.link_with_query(name,
                             controller: :observer,
                             action: :show_rss_log,
                             id: rss_log.id)
      end
    self.where = view.location_link(target.place_name, target.location) \
                 if target&.respond_to?(:location)
    self.detail = rss_log.detail.notice + rss_log.detail.by
    self.time = rss_log.updated_at

    self.thumbnail =
      if target&.respond_to?(:thumb_image) && target&.thumb_image
        view.thumbnail(target.thumb_image,
                       link: { controller: target.show_controller,
                               action: target.show_action, id: target.id })
      end
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
    self.what = view.link_with_query(name,
                                     controller: image.show_controller,
                                     action: image.show_action,
                                     id: image.id)
    self.thumbnail = view.thumbnail(image,
                                    link: { controller: image.show_controller,
                                            action: image.show_action,
                                            id: image.id },
                                    responsive: true)
  end

  # Grabs all the information needed for view from Observation instance.
  def observation_to_presenter(observation, view)
    name = observation.unique_format_name.t
    self.when  = observation.when.web_date
    self.who   = view.user_link(observation.user) if observation.user
    self.what  = view.link_with_query(name, controller: :observer,
                                            action: :show_observation,
                                            id: observation.id)
    self.where = view.location_link(observation.place_name,
                                    observation.location)
    return unless observation.rss_log

    self.detail = observation.rss_log.detail.notice
    self.time = observation.rss_log.updated_at
    return unless observation.thumb_image

    self.thumbnail =
      view.thumbnail(observation.thumb_image,
                     link: { controller: :observer,
                             action: :show_observation,
                             id: observation.id })
  end

  # Grabs all the information needed for view from User instance.
  def user_to_presenter(user, view)
    name = user.unique_text_name
    self.detail = "#{:list_users_joined.t}: #{user.created_at.web_date}<br/>
                   #{:list_users_contribution.t}: #{user.contribution}<br/>
                   #{:Observations.t}: #{user.observations.count}".html_safe
    self.what  = view.link_with_query(name, action: :show_user, id: user.id)
    self.where = view.location_link(nil, user.location) if user.location
    return unless user.image_id

    self.thumbnail =
      view.thumbnail(user.image_id,
                     link: { controller: user.show_controller,
                             action: user.show_action,
                             id: user.id }, votes: false)
  end

  def fancy_time
    time&.fancy_time
  end
end
