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
    get_rss_log_details(rss_log, target)
    self.when  = target.when.web_date if target && target.respond_to?(:when)
    self.who   = view.user_link(target.user) if target && target.user
    self.what  = target ?
      view.link_with_query(name, controller: target.show_controller, action: target.show_action, id: target.id) :
      view.link_with_query(name, controller: :observer, action: :show_rss_log, id: rss_log.id)
    self.where = view.location_link(target.place_name, target.location) \
                 if target && target.respond_to?(:location)
    self.thumbnail = view.thumbnail(target.thumb_image, link: { controller: target.show_controller,
                                                                action: target.show_action, id: target.id }) \
                     if target && target.respond_to?(:thumb_image) && target.thumb_image
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
    self.what = view.link_with_query(name, controller: image.show_controller,
                                           action: image.show_action, id: image.id)
    self.thumbnail = view.thumbnail(image, link: { controller: image.show_controller,
                                                   action: image.show_action, id: image.id }, responsive: true)
  end

  # Grabs all the information needed for view from Observation instance.
  def observation_to_presenter(observation, view)
    name = observation.unique_format_name.t
    get_rss_log_details(observation.rss_log, observation)
    self.when  = observation.when.web_date
    self.who   = view.user_link(observation.user) if observation.user
    self.what  = view.link_with_query(name, controller: :observer,
                                            action: :show_observation, id: observation.id)
    self.where = view.location_link(observation.place_name, observation.location)
    self.thumbnail = view.thumbnail(observation.thumb_image, link: { controller: :observer,
                                                                     action: :show_observation, id: observation.id }) \
                     if observation.thumb_image
  end

  # Grabs all the information needed for view from User instance.
  def user_to_presenter(user, view)
    name = user.unique_text_name
    self.detail = "#{:list_users_joined.t}: #{user.created_at.web_date}<br/>
                   #{:list_users_contribution.t}: #{user.contribution}<br/>
                   #{:Observations.t}: #{user.observations.count}".html_safe
    self.what  = view.link_with_query(name, action: :show_user, id: user.id)
    self.where = view.location_link(nil, user.location) if user.location
    self.thumbnail = view.thumbnail(user.image_id, link: { controller: user.show_controller,
                                                           action: user.show_action, id: user.id }, votes: false) \
                     if user.image_id
  end

  def fancy_time
    time.fancy_time if time
  end

  private

  # Figure out what the detail messages should be.
  # TODO: This should probably all live in RssLog.
  def get_rss_log_details(rss_log, target)
    target_type = target ? target.type_tag : rss_log.target_type
    begin
      tag, args, time = rss_log.parse_log.first
    rescue StandardError
      []
    end
    if !target_type
      self.detail = :rss_destroyed.t(type: :object)
    elsif !target || tag.to_s.match(/^log_#{target_type.to_s}_(merged|destroyed)/)
      self.detail = :rss_destroyed.t(type: target_type)
    elsif !time || time < target.created_at + 1.minute
      self.detail = :rss_created_at.t(type: target_type)
      unless target_type == :observation || target_type == :species_list
        begin
          self.detail += " ".html_safe + :rss_by.t(user: target.user.legal_name)
        rescue StandardError
          nil
        end
      end
    else
      if [:observation, :species_list].include?(target_type) &&
         [target.user.login, target.user.name, target.user.legal_name].include?(args[:user])
        # This will remove redundant user from observation logs.
        tag2 = :"#{tag}0"
        self.detail = tag2.t(args) if tag2.has_translation?
      end
      unless self.detail
        tag2 = tag.to_s.sub(/^log/, "rss").to_sym
        self.detail = tag2.t(args) if tag2.has_translation?
      end
      begin
        self.detail ||= tag.t(args)
      rescue StandardError
        nil
      end
    end
    time ||= rss_log.updated_at if rss_log
    self.time = time
  end
end
