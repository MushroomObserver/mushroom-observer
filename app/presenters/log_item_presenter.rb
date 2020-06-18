# frozen_string_literal: true

# TODO: Fix thumbnail
# Name, location, and image all have presentation markup baked in
# HTML markup should be in the views or partials
class LogItemPresenter
  attr_accessor \
    :thumbnail, # thumbnail image tag
    :what,      # link to object or target

    # :query,     # how to find object or target
    :name,      # name of object or target
    :author,    # author of name
    :id,        # id of object or target

    :when,      # when object or target was created
    :who,       # owner of object or target
    :where,     # location of object or target
    :detail,    # string with extra details
    :time       # when object or target was last modified

  def initialize(object, view)
    case object
    when RssLog
      rss_log_to_presenter(object, view)
    when Image
      image_to_presenter(object, view)
    when Observation
      observation_to_presenter(object, view)
    when User
      user_to_presenter(object, view)
    end
  end

  # Grabs all the information needed for view from RssLog instance.
  def rss_log_to_presenter(rss_log, view)
    target = rss_log.target
    target = rss_log unless target.respond_to?(:name)

    # TODO: fix other objects RSS log could target..
    # case target
    # when location || name || project || species_list || glossary_term
    # end

    # target_type = target ? target.type_tag : rss_log.target_type

    # get_rss_log_details(rss_log, target)

    self.what = target
    self.name = target.format_name.delete_suffix(target.name.author).t
    self.author =
      if target.name.respond_to?(:author)
        target.name.author
      else
        ""
      end
    self.id = target.id

    self.where = view.location_link(target.place_name, target.location) \
                 if target&.respond_to?(:location)
    self.when  = target.when.web_date if target&.respond_to?(:when)
    self.who   = view.user_link(target.user) if target&.user
    self.thumbnail =
      if target&.respond_to?(:thumb_image) &&
         target&.thumb_image &&
         target&.thumb_image&.content_type
        view.thumbnail(target.thumb_image,
                       link: {
                         controller: target.show_controller,
                         action: target.show_action,
                         id: target.id
                       })
      end
    self.detail = rss_log.detail
    self.time = rss_log.updated_at
  end

  # Grabs all the information needed for view from Observation instance.
  def observation_to_presenter(observation, view)
    self.what = observation
    if observation.name.respond_to?(:author)
      self.name   = observation.format_name.
                    delete_suffix(observation.name.author).t
      self.author = observation.name.author
    else
      self.name = observation.format_name
      self.author = ""
    end
    self.id     = observation.id
    self.when   = observation.when.web_date if observation.when
    self.who    = view.user_link(observation.user) if observation.user
    # self.what  = view.link_with_query(name, controller: :observations,
    #                                         action: :show,
    #                                         id: observation.id)
    self.where  = view.location_link(observation.place_name,
                                     observation.location)
    return unless observation.thumb_image

    self.thumbnail =
      view.thumbnail(observation.thumb_image,
                     link: { controller: :observations,
                             action: :show,
                             id: observation.id })
    return unless observation.rss_log

    self.detail = observation.rss_log.detail
    self.time = observation.rss_log.updated_at
  end

  # Grabs all the information needed for view from Image instance.
  def image_to_presenter(image, view)
    name = image.unique_format_name.t
    self.when = image.when.web_date if image.when
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

  # Grabs all the information needed for view from User instance.
  def user_to_presenter(user, view)
    name = user.unique_text_name
    self.detail = "#{:list_users_joined.t}: #{user.created_at.web_date}<br/>
                   #{:list_users_contribution.t}: #{user.contribution}<br/>
                   #{:Observations.t}: #{user.observations.count}".html_safe
    self.what  = view.link_with_query(name,
                                      controller: :users,
                                      action: :show,
                                      id: user.id)
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
