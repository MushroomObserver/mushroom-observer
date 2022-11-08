# frozen_string_literal: true

# Name Published Email

class QueuedEmail::Publish < QueuedEmail
  def name
    get_object(:name, ::Name)
  end

  def self.create_email(publisher, receiver, name)
    result = create(publisher, receiver)
    raise("Missing name!") unless name

    result.add_integer(:name, name.id)
    result.finish
    result
  end

  def deliver_email
    PublishNameMailer.build(user, to_user, name).deliver_now
  end
end
