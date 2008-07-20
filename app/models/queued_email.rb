class QueuedEmail < ActiveRecord::Base
  has_many :queued_email_integers,      :dependent => :destroy
  has_many :queued_email_strings,       :dependent => :destroy
  has_one :queued_email_note,           :dependent => :destroy
  belongs_to :user
  belongs_to :to_user, :class_name => "User", :foreign_key => "to_user_id"
  
  # Returns: array of symbols.  Essentially a constant array.
  def self.all_flavors()
    [:comment, :feature]
  end

  # Like initialize, but ensures that the objects is saved
  # and is ready to have parameters added.
  def setup(sender, receiver, flavor)
    self.user = sender
    self.to_user = receiver
    self.flavor = flavor
    self.queued = Time.now()
    self.save()
  end

  # Centralized place to hang code after all the parameters are set.
  # For now it makes sure the email is sent if queuing is disabled.
  def finish
    unless QUEUE_EMAIL
      self.send_email
    end
  end
  
  # Have to use cheesy dispatch since the object returned from the database
  # can only be a QueuedEmail.  Might be able to solve this in a better way
  # if there is some clever way that a constructor for a class could return
  # a subclass of that class.  Note that the initialize functions for the
  # subclasses would have to be changed (no save or adding values that do
  # saves as a side effect).
  def deliver_email
    case self.flavor
    when :comment
      CommentEmail.deliver_email(self)
    when :feature
      FeatureEmail.deliver_email(self)
    else
      raise NotImplementedError
    end
  end
  
  # The different types of email should be handled by separate classes
  def send_email
    result = false
    begin
      self.deliver_email
      result = true
    rescue
      print "Unable to send queued email #{self.id}\n"
      # Failing to send email should not throw an error in production
      raise unless ENV['RAILS_ENV'] == 'production'
    end
    result
  end
  
  # Methods for adding additional data
  def add_integer(key, value)
    result = QueuedEmailInteger.new()
    result.queued_email = self
    result.key = key.to_s
    result.value = value
    result.save()
    result
  end
  
  def get_integers(keys)
    dict = {}
    for qi in self.queued_email_integers
      dict[qi.key] = qi.value
    end
    result = []
    for key in keys
      result.push(dict[key.to_s])
    end
    result
  end

  def set_note(value)
    result = QueuedEmailNote.new()
    result.queued_email = self
    result.value = value
    result.save()
    result
  end
end
