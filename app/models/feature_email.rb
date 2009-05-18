class FeatureEmail < QueuedEmailSubclass
  attr_accessor :note

  def initialize(email)
    self.note = email.queued_email_note.value
    super(email)
  end

  def self.create_email(receiver, note)
    result = QueuedEmail.new()
    result.setup(nil, receiver, :feature)
    result.save()
    result.set_note(note)
    result.finish()
    result
  end
  
  def deliver_email
    if !note
      raise "No note found for email ##{self.id}"
    elsif to_user.feature_email # Make sure it hasn't changed
      AccountMailer.deliver_email_features(to_user, note)
    end
  end
end
