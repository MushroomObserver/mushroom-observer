# encoding: utf-8
#
#  = RSS Log Helpers.
# Helps transforms RSS Logs into something usable by the view.
#
#
################################################################################
##TODO: Add unit test once current tests work
module RssLogHelper
  # @param [Object] target
  def to_rss_feed_item(target)
  target_type = target ? target.type_tag : rss_log.target_type
  target_name = target ? target.unique_format_name.t : rss_log.unique_format_name.t
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

  return target, target_type, target_name, title, detail, time
  end
end



