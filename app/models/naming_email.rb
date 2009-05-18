class NamingEmail < QueuedEmailSubclass
  attr_accessor :naming
  attr_accessor :notification

  def initialize(email)
    self.naming       = Naming.find(email.get_integer(:naming))
    self.notification = Notification.find(email.get_integer(:notification))
    super(email)
  end

  def self.create_email(notification, naming)
    sender = notification.user
    observer = naming.observation.user
    result = nil
    if sender != observer
      result = QueuedEmail.new()
      result.setup(sender, observer, :naming)
      result.save()
      result.add_integer(:naming, naming.id)
      result.add_integer(:notification, notification.id)
      result.finish()
    end
    result
  end
  
  def deliver_email
    if !naming
      raise "No naming found for email ##{self.id}"
    elsif user == to_user
      print "Skipping email with same sender and recipient, #{user.email}\n" if !TESTING
    else
      AccountMailer.deliver_naming_for_tracker(user, naming)
      if notification && notification.note_template
        AccountMailer.deliver_naming_for_observer(to_user, naming, notification)
      end
    end
  end
end
