class QueuedEmailSubclass
  attr_accessor :email

  def initialize(email)
    self.email = email
  end

  def method_missing(name, *args, &block)
    email.send(name, *args, &block)
  end
end
