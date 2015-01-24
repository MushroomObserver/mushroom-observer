class RssLogPresenter
  attr_accessor :title, :name, :detail, :when, :location, :target, :who, :thumbnail, :what, :fancy_time

  def initialize(target, rss_log, view)
    self.target = target

    target_type = target ? target.type_tag : rss_log.target_type
    tag, args, time = rss_log.parse_log.first rescue []
    if not target_type
      title = :rss_destroyed.t(:type => :object)
      detail = nil
    elsif not target or
        tag.to_s.match(/^log_#{target_type.to_s}_(merged|destroyed)/)
      title = :rss_destroyed.t(:type => target_type)
      detail = tag.t(args) rescue nil
    elsif not time or time < target.created_at + 1.minute
      title = :rss_created_at.t(:type => target_type)
      if target_type == :observation || target_type == :species_list
        #detail = nil
      else
        detail = :rss_by.t(:user => target.user.legal_name) rescue nil
      end
    else
      title = :rss_changed.t(:type => target_type)
      detail = nil
      if (target_type == :observation ||
          target_type == :species_list) and
          (args[:user] == target.user.login ||
              args[:user] == target.user.name ||
              args[:user] == target.user.legal_name)
        # This will remove redundant user from observation logs.
        tag2 = :"#{tag}0"
        if tag2.has_translation?
          detail = tag2.t(args)
        end
      end
      if !detail
        tag2 = tag.to_s.sub(/^log/,'rss').to_sym
        if tag2.has_translation?
          detail = tag2.t(args)
        end
      end
      detail ||= tag.t(args) rescue nil
    end
    time ||= rss_log.updated_at rescue nil

    self.detail = detail
    self.title = title
    self.fancy_time =  time.respond_to?('fancy_time')  ? time.fancy_time :  ''
    self.name = target ? target.unique_format_name.t : rss_log.unique_format_name.t
    self.when = target.respond_to?('when') ? target.when.web_date : ''
    self.who = view.respond_to?('user_link') ? view.user_link(target.user) : ''
    self.what = view.link_with_query(self.name, :controller => target.show_controller,
                                 :action => target.show_action, :id => target.id)
    self.location = target.respond_to?('place_name') ? view.location_link(target.place_name, target.location) : ''
    self.thumbnail = target.respond_to?('thumb_image') ? view.render(:partial  => '/image/image_thumbnail',
                                                                :locals => {:image => target.thumb_image}) : ''
  end
end

