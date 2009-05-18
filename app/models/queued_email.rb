################################################################################
#
#  Model to describe a single email.  There are several related classes in a
#  somewhat complicated relationship, so I'm going to describe them all here.
#
#    QueuedEmail              Central database record; one of these per email.
#   
#                             Each email can have arbitrary associated data:
#    QueuedEmailInteger         zero or more integers
#    QueuedEmailString          zero or more fixed-length strings
#    QueuedEmailNote            zero or one arbitrary-length strings
#   
#    CommentEmail             These classes own a QueuedEmail record; they know
#    FeatureEmail             which data are required for their email type, how
#    NameChangeEmail          to store it, retreive it, and how to deliver the
#    etc.                     actual mail (via AccountMailer).
#   
#    BaseEmail                Base class for XxxxEmail classes.  Defines the
#                             has-a relationship between the XxxxEmail and
#                             QueuedEmail classes.
#   
#    AccountMailer            This is the "class" that actually sends email.
#                             It is never instantiated or anything, so it's
#                             really just a collection of subroutines.  (Class
#                             methods to be more precies.)
#
# ----------------------------------------------------------------------------
#
#  The typical execution flow would be:
#
#    1. User takes some action that triggers an email (e.g. posting a comment)
#    2. The controller involved will queue the appropriate email with:
#   
#         CommentEmail.create(from, to, comment)
#   
#    3. This class method creates a QueuedEmail record, and attaches any data
#       it needs (in this case just one integer for the Comment ID).
#    4. That's it for a while. The record (and data) describing the email sit
#       in the database until a cronjob deems it time to finally send it.
#    5. (In the meantime some email records might actually be updated, e.g. if
#       a user quickly turns around and edits their comment.)
#    6. The cronjob runs:
#   
#         rake email:send
#   
#       which in turn looks up QueuedEmail records and delivers them once
#       they've been around long enough.  It does this with:
#    
#         queued_email.send_email()
#   
#    7. QueuedEmail immediately instantiates the appropriate subclass of
#       BaseEmail and calls:
#   
#         comment_email.deliver_email()
#   
#    8. CommentEmail grabs all the attached data it needs (often done in the
#       constructor, actually), and calls the appropriate AccountMailer method:
#   
#         AccountMailer.comment(from, to, observation, comment)
#   
#    9. AccountMailer renders the email message and dispatches it to postfix
#       or whichever mailserver is responsible for delivering email.
#
# ----------------------------------------------------------------------------
#
#  QueuedEmail's basic properties are:
#
#    1. has a flavor (:comment, :feature, :name_change, etc.)
#    2. has a sender (called "user")
#    3. has a receiver (called "to_user")
#    4. has a time (called "queued" -- when it was last modified)
#    5. has zero or more queued_email_integers
#    6. has zero or more queued_email_strings
#    7. has zero or one queued_email_note
#
#  Class Methods:
#
#    QE.all_flavors                 List of allowable flavors.
#    QE.queue_emails(true)          Turn queuing on in test suite.
#
#  Instance Methods:
#
#    qe.setup(from, to, flavor)     Initialize and save.
#    qe.finish                      Does nothing.
#    qe.send_email                  Calls send_email, catching errors.
#    qe.deliver_email               Calls XxxxEmail.new().deliver_email().
#    qe.dump                        Dumps all info about email to a string.
#
#    qe.add_integer(key, val)       Add one integer.
#    qe.add_string(key, val)        Add one fixed-length string.
#    qe.set_note(value)             Create arbitrary-length string.
#
#    qe.get_integer(key)            Retrieve one integer.
#    qe.get_string(key)             Retrieve one fixed-length string.
#    qe.get_note                    Retrieve the arbitrary-length string.
#
#    qe.get_integers(keys)          Get integers for given array of keys.
#    qe.get_integers(keys, true)    Same but returns hash instead of array.
#    qe.get_strings(keys)           Get strings for given array of keys.
#    qe.get_strings(keys, true)     Same but but returns hash instead of array.
#
################################################################################

class QueuedEmail < ActiveRecord::Base
  has_many :queued_email_integers,      :dependent => :destroy
  has_many :queued_email_strings,       :dependent => :destroy
  has_one :queued_email_note,           :dependent => :destroy
  belongs_to :user
  belongs_to :to_user, :class_name => "User", :foreign_key => "to_user_id"

  # Returns: array of symbols.  Essentially a constant array.
  def self.all_flavors()
    [:comment, :feature, :naming, :publish, :name_proposal, :consensus_change, :name_change]
  end

  # This lets me turn queuing on in unit tests.
  @@queue = false
  def self.queue_emails(state)
    @@queue = state
  end

  # Like initialize, but ensures that the objects is saved
  # and is ready to have parameters added.
  def setup(sender, receiver, flavor)
    self.user_id = sender ? sender.id : 0
    self.to_user = receiver
    self.flavor = flavor
    self.queued = Time.now()
    self.save()
  end

  # Centralized place to hang code after all the parameters are set.
  # For now it makes sure the email is sent if queuing is disabled.
  def finish
    unless QUEUE_EMAIL || @@queue
      self.send_email
    end
  end

  # The different types of email should be handled by separate classes
  def send_email
    result = nil
    begin
      result = self.deliver_email
    rescue
      print "Unable to send queued email:\n"
      self.dump()
      # Failing to send email should not throw an error in production
      raise unless ENV['RAILS_ENV'] == 'production'
    end
    result
  end

  # This instantiates an instance of the specific email type, then
  # tells it to deliver the mail.
  def deliver_email
    class_name = self.flavor.to_s.camelize + "Email"
    email = class_name.constantize.new(self)
    email.deliver_email
    return email
  end

  # Print out all the info about a QueuedEmail
  def dump
    print "#{self.id}: from => #{self.user and self.user.login}, to => #{self.to_user.login}, flavor => #{self.flavor}, queued => #{self.queued}\n"
    for i in self.queued_email_integers
      print "\t#{i.key.to_s} => #{i.value}\n"
    end
    for i in self.queued_email_strings
      print "\t#{i.key.to_s} => #{i.value}\n"
    end
    if self.queued_email_note
      print "\tNote: #{self.queued_email_note.value}\n"
    end
  end

  # ----------------------------
  #  Methods for getting data.
  # ----------------------------

  def get_integer(key)
    begin
      self.queued_email_integers.select {|qi| qi.key == key.to_s}.first.value
    rescue
    end
  end

  def get_string(key)
    begin
      self.queued_email_strings.select {|qs| qs.key == key.to_s}.first.value
    rescue
    end
  end

  def get_note
    begin
      self.queued_email_note.value
    rescue
    end
  end

  def get_integers(keys, return_dict=false)
    dict = {}
    for qi in self.queued_email_integers
      dict[qi.key] = qi.value
    end
    if return_dict
      result = dict
    else
      result = []
      for key in keys
        result.push(dict[key.to_s])
      end
    end
    result
  end

  def get_strings(keys, return_dict=false)
    dict = {}
    for qs in self.queued_email_strings
      dict[qs.key] = qs.value
    end
    if return_dict
      result = dict
    else
      result = []
      for key in keys
        result.push(dict[key.to_s])
      end
    end
    result
  end

  # --------------------------------------
  #  Methods for adding additional data.
  # --------------------------------------

  def add_integer(key, value)
    result = QueuedEmailInteger.new()
    result.queued_email = self
    result.key = key.to_s
    result.value = value
    result.save()
    result
  end

  def add_string(key, value)
    result = QueuedEmailString.new()
    result.queued_email = self
    result.key = key.to_s
    result.value = value
    result.save()
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
