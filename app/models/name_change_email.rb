# Class for holding code specific to QueuedEmails intended to send email_naming emails.
#
# The separation is nice, but it kind of violates some of Rails assumptions.  In particular,
# the initialize if dangerous since it does saves.  However, I can't figure out a way to
# get these out of the database so as long the creation is explicit in code things should
# be fine.
class NameChangeEmail < QueuedEmail
  def self.create_email(sender, recipient, name, review_status_changed)
    result = NameChangeEmail.new()
    result.setup(sender, recipient, :name_change)
    result.save()
    result.name = name
    result.new_version = name.version
    result.old_version = (name.altered? ? name.version - 1 : name.version)
    result.review_status = review_status_changed ? name.review_status : :no_change
    result.finish()
    result
  end

  # While this looks like it could be an instance method, it has to be a class
  # method for QueuedEmails that come out of the database to work.  See queued_emails.rb
  # for more details.
  def deliver_email
    if !name
      print "No name found for email ##{self.id}.\n"
    elsif user == to_user
      print "Skipping email with same sender and recipient: #{user.email}\n" if !TESTING
    else
      AccountMailer.deliver_name_change(user, to_user, queued, name,
                                        old_version, new_version, review_status)
    end
  end

  # ----------------------------
  #  Accessors
  # ----------------------------

  def name=(name)
    @name = name
    self.add_integer(:name, name.id);
  end

  def old_version=(version)
    @old_version = version
    self.add_integer(:old_version, version)
  end

  def new_version=(version)
    @new_version = version
    self.add_integer(:new_version, version)
  end

  def review_status=(status)
    @review_status = status
    self.add_string(:review_status, status)
  end

  def name
    begin
      @name ||= Name.find(self.get_integer(:name))
    rescue
    end
    @name
  end

  def old_version
    @old_version ||= self.get_integer(:old_version)
  end

  def new_version
    @new_version ||= self.get_integer(:new_version)
  end

  def review_status
    @review_status ||= self.get_string(:review_status).to_sym
  end
end
