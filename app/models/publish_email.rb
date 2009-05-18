class PublishEmail < BaseEmail
  attr_accessor :name

  def initialize(email)
    self.name = Name.find(email.get_integer(:name))
    super(email)
  end

  def self.create_email(publisher, receiver, name)
    result = QueuedEmail.new()
    result.setup(publisher, receiver, :publish)
    result.save()
    result.add_integer(:name, name.id)
    result.finish()
    result
  end
  
  def deliver_email
    if !name
      raise "No name found for email ##{self.id}"
    elsif user == to_user
      print "Skipping email with same sender and recipient, #{user.email}\n" if !TESTING
    else
      AccountMailer.deliver_publish_name(user, to_user, name)
    end
  end
end
