################################################################################
#
#  See the documentation under app/models/queued_email.rb for more information
#  about how the various email classes work together.
#
#  This is the base class for all the specific email types, like CommentEmail,
#  FeatureEmail and NameChangeEmail.  All of these are associated with an
#  instance of QueuedEmail by a has-a relationship: BaseEmail contains a
#  QueuedEmail record.  Each instance of a BaseEmail subclass corresponds to
#  one actual email.  They are responsible for storing and retrieving the info
#  in the email queue required to create an email message.
#
#  Each subclass has the following properties:
#
#    1. has a QueuedEmail instance (called "email")
#
#  Class methods:
#
#    BE.new(email)
#
#  Instance methods:
#
#    be.user
#    be.to_user
#    be.flavor
#    be.queued
#
#    be.get_integer
#    be.get_string
#    be.get_note
#    be.add_integer
#    be.add_string
#    be.set_note
#    etc.
#
################################################################################

class BaseEmail
  attr_accessor :email

  def initialize(email)
    self.email = email
  end

  # Don't want these methods falling through to QueuedEmail.
  def setup; end
  def finish; end
  def send_email; end
  def deliver_email; end

  # Maybe we should explicitly state the ones we want to fall through, instead
  # of the other way around?...
  def method_missing(name, *args, &block)
    email.send(name, *args, &block)
  end
end
