class NameChangeEmail < QueuedEmailSubclass
  attr_accessor :name
  attr_accessor :old_version
  attr_accessor :new_version
  attr_accessor :review_status

  def initialize(email)
    self.name          = Name.find(email.get_integer(:name))
    self.old_version   = email.get_integer(:old_version)
    self.new_version   = email.get_integer(:new_version)
    self.review_status = email.get_string(:review_status).to_sym
    super(email)
  end

  def self.create_email(sender, recipient, name, review_status_changed)
    result = QueuedEmail.new()
    result.setup(sender, recipient, :name_change)
    result.save()
    result.add_integer(:name, name.id)
    result.add_integer(:new_version, name.version)
    result.add_integer(:old_version, (name.altered? ? name.version - 1 : name.version))
    result.add_string(:review_status, review_status_changed ? name.review_status : :no_change)
    result.finish()
    result
  end

  def deliver_email
    if !name
      raise "No name found for email ##{self.id}"
    elsif user == to_user
      print "Skipping email with same sender and recipient: #{user.email}\n" if !TESTING
    else
      AccountMailer.deliver_name_change(user, to_user, queued, name,
                                        old_version, new_version, review_status)
    end
  end
end
