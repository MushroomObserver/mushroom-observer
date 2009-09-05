class FeatureEmail < BaseEmail
  attr_accessor :note

  def initialize(email)
    self.note = email.get_note
    super(email)
  end

  def self.create_email(receiver, content)
    result = QueuedEmail.new()
    result.setup(nil, receiver, :feature)
    result.save()
    result.set_note(content)
    result.finish()
    result
  end
  
  def deliver_email
    if !note
      raise "No note found for email ##{email.id}"
    elsif to_user.email_general_feature # Make sure it hasn't changed
      AccountMailer.deliver_email_features(to_user, note)
    end
  end
end
