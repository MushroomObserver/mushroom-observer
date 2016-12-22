# encoding: utf-8
class Comment
  #
  #  = Comment Callbacks
  #
  #  notify_users::   Sends notification emails after creation.
  #  oil_and_water::  Sends admin email if users start to bicker.
  #
  module Callbacks
    protected

    # Callback called after creation.  Lots of people potentially can receive
    # an email whenever a Comment is posted:
    #
    # 1. the owner of the object
    # 2. users who already commented on the same object
    # 3. users who have expressed Interest in that object
    # 4. users masochistic enough to want to be notified of _all_ comments
    # 5. users highlighted in the comment itself
    #
    def notify_users
      return unless target
      recipients = []
      add_owners_and_authors!(recipients)
      add_users_interested_in_all_comments!(recipients)
      add_users_with_comments_on_same_target!(recipients)
      add_highlighted_users!(recipients, "#{summary}\n#{comment}")
      add_interested_users!(recipients)
      recipients.delete(user)
      send_comment_notifications(recipients.uniq)
    end

    def add_owners_and_authors!(users)
      users.concat(owners_and_authors.
                   select(&:email_comments_owner))
    end

    def add_users_interested_in_all_comments!(users)
      users.concat(User.where(email_comments_all: true))
    end

    def add_users_with_comments_on_same_target!(users)
      users.concat(users_with_comments_on_same_target.
                   select(&:email_comments_response))
    end

    def add_interested_users!(recipients)
      Interest.where_target(target).each do |interest|
        if interest.state
          recipients.push(interest.user)
        else
          recipients.delete(interest.user)
        end
      end
    end

    def send_comment_notifications(users)
      users.each do |recipient|
        QueuedEmail::CommentAdd.find_or_create_email(user, recipient, self)
      end
    end

    def owners_and_authors
      target.respond_to?(:authors) ? target.authors || [] : [target.user]
    end

    def users_with_comments_on_same_target
      Comment.where(target_type: target.class.to_s, target_id: target.id).
        map(&:user).uniq
    end

    USER_LINK_PAT  = /(?:^|\W) _+user\s+ ([^_\s](?:[^_\n]+[^_\s])?) _+ (?!\w)/xi
    AT_USER_AT_PAT = /(?:^|\W) @ ([^@\n]+) @/x
    AT_USER_PAT    = /(?:^|\W) @ (\w+) [^@]/x

    def highlighted_users(str)
      users = []
      users += search_for_highlighted_users(str, USER_LINK_PAT)
      users += search_for_highlighted_users(str, AT_USER_AT_PAT)
      users += search_for_highlighted_users(str, AT_USER_PAT)
      users.uniq.reject(&:nil?).select(&:email_comments_response)
    end

    def search_for_highlighted_users(str, regex)
      users = []
      while str.match(regex)
        str = Regexp.last_match.pre_match + "\n" + Regexp.last_match.post_match
        users << lookup_user(Regexp.last_match(1))
      end
      users
    end

    def lookup_user(name)
      if name =~ /^\d+$/
        User.safe_find(name)
      else
        User.find_by_login(name) || User.find_by_name(name)
      end
    end

    # Notify webmaster when comments get fiery on an observation.
    # We keep two lists of users, one on each side of a "lively" debate.
    # Send notifications when at least one user from both lists comments on
    # the same comment.
    def oil_and_water
      user_ids = users_with_comments_on_same_target.map(&:id).sort
      return unless (user_ids & MO.water_users).any?
      return unless (user_ids & MO.oil_users).any?
      WebmasterEmail.build(
        MO.noreply_email_address,
        oil_and_water_content(user_ids),
        oil_and_water_subject
      ).deliver_now
    end

    def oil_and_water_subject
      "Oil and water on #{target_type} ##{target_id}"
    end

    def oil_and_water_content(user_ids)
      show_url = target ? target.show_url : "(can't find object?!)"
      logins   = User.where_id(user_ids).map(&:login)
      "#{show_url}\nAll users: #{logins.join(", ")}\n\n" \
      "User: #{user.login}\nSummary: #{summary}\n\n#{comment}"
    end
  end
end
