# encoding: utf-8

# Feature Email

class QueuedEmail::Feature < QueuedEmail
  def content; get_note; end

  def self.create_email(receiver, content)
    result = create(nil, receiver)
    raise "Missing content!" if !content
    result.set_note(content)
    result.finish
    return result
  end
  
  def deliver_email
    if to_user.email_general_feature # Make sure it hasn't changed
      FeaturesEmail.build(to_user, content).deliver
    end
  end
end
