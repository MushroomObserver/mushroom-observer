class LocationChangeEmail < BaseEmail
  attr_accessor :location
  attr_accessor :old_version
  attr_accessor :new_version

  def initialize(email)
    self.location    = Location.find(email.get_integer(:location))
    self.old_version = email.get_integer(:old_version)
    self.new_version = email.get_integer(:new_version)
    super(email)
  end

  def self.create_email(sender, recipient, location)
    result = QueuedEmail.new()
    result.setup(sender, recipient, :location_change)
    result.save()
    result.add_integer(:location, location.id)
    result.add_integer(:new_version, location.version)
    result.add_integer(:old_version, (location.altered? ? location.version - 1 : location.version))
    result.finish()
    result
  end

  def deliver_email
    if !location
      raise "No location found for email ##{self.id}"
    elsif user == to_user
      print "Skipping email with same sender and recipient: #{user.email}\n" if !TESTING
    else
      AccountMailer.deliver_location_change(user, to_user, queued, location,
                                            old_version, new_version)
    end
  end
end
