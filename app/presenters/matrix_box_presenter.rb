class MatrixBoxPresenter
  attr_accessor :title, :name, :detail, :when, :location, :target, :who, :thumbnail, :what, :fancy_time

  def initialize(object, view)
    case object
      when RssLog
        rss_log_to_presenter(object, view)
      when Image
        image_to_presenter(object, view)
      when User
        user_to_presenter(object, view)
    end

  end

  #Private
  def rss_log_to_presenter(object, view)  ##TODO: Can someone that understands the implications of the code here, clean it up?
    rss_log = object
    target = self.target = object.target

    target_type = target ? target.type_tag : rss_log.target_type
    tag, args, time = rss_log.parse_log.first rescue []
    if not target_type
      self.title = :rss_destroyed.t(:type => :object)
    elsif not target or tag.to_s.match(/^log_#{target_type.to_s}_(merged|destroyed)/)
      self.title = :rss_destroyed.t(:type => target_type)
    elsif not time or time < target.created_at + 1.minute
      self.title = :rss_created_at.t(:type => target_type)
      unless (target_type == :observation || target_type == :species_list)
        self.detail = :rss_by.t(:user => target.user.legal_name) rescue nil
      end
    else
      self.title = :rss_changed.t(:type => target_type)
      if (target_type == :observation ||
          target_type == :species_list) and
          (args[:user] == target.user.login ||
              args[:user] == target.user.name ||
              args[:user] == target.user.legal_name)
        # This will remove redundant user from observation logs.
        tag2 = :"#{tag}0"
        if tag2.has_translation?
          self.detail = tag2.t(args)
        end
      end
      if !self.detail
        tag2 = tag.to_s.sub(/^log/, 'rss').to_sym
        if tag2.has_translation?
          self.detail = tag2.t(args)
        end
      end
      self.detail ||= tag.t(args) rescue nil
    end
    time ||= rss_log.updated_at rescue nil

    self.fancy_time = time.respond_to?('fancy_time') ? time.fancy_time : ''
    self.name = target ? target.unique_format_name.t : rss_log.unique_format_name.t
    self.when = target.respond_to?('when') ? target.when.web_date : ''
    self.who = view.respond_to?('user_link') ? view.user_link(target.user) : ''
    self.what = view.link_with_query(self.name, :controller => target.show_controller,
                                     :action => target.show_action, :id => target.id)
    self.location = target.respond_to?('place_name') ? view.location_link(target.place_name, target.location) : ''
    self.thumbnail = target.respond_to?('thumb_image') && target.thumb_image ? view.thumbnail(target.thumb_image,
                                                                                              :link => {controller: target.show_controller,
                                                                                                        action: target.show_action,
                                                                                                        id: target.id}) : ''
  end
  # Converts an image objects into a presenter
  def image_to_presenter(object, view)
    target = object
    self.detail = ''
    self.title = ''
    self.name = target ? target.unique_format_name.t : ''
    self.when = target.respond_to?('when') ? target.when.web_date : ''
    self.who = view.respond_to?('user_link') ? view.user_link(target.user) : ''
    self.what = view.link_with_query(self.name, :controller => target.show_controller,
                                     :action => target.show_action, :id => target.id)
    self.location = target.respond_to?('place_name') ? view.location_link(target.place_name, target.location) : ''
    self.thumbnail = view.thumbnail(target,:link => {controller: target.show_controller,
                                                         action: target.show_action,
                                                         id: target.id})
  end

  def user_to_presenter(user, view)
    self.thumbnail = user.image_id ? view.thumbnail(user.image_id, :link =>
                                                                     {controller: user.show_controller,
                                                                      action: user.show_action,
                                                                      id: user.id},
                                                                      :votes => false) : ''

    self.what = view.link_with_query(user.unique_text_name, :action => 'show_user',
        :id => user.id)
    self.location = user.location ? view.location_link(nil, user.location) : ''
    self.detail = "#{:list_users_joined.t}: #{user.created_at.web_date}
              <br> #{:list_users_contribution.t}: #{user.contribution}
              <br> #{:Observations.t}: #{user.observations.count}".html_safe

  end
end

