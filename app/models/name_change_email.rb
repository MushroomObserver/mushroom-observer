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

    # Save review status as integer: -1 = no change, 0 to n = index in list of allowable values.
    review_status = -1
    if review_status_changed
      review_status = Name.all_review_statuses.index(name.review_status) || -1
    end

    result.add_integer(:name, name.id)
    result.add_integer(:new_version, name.version)
    result.add_integer(:old_version, name.altered? ? name.version - 1 : name.version)
    result.add_integer(:review_status, review_status)
    result.finish()
    result
  end

  # While this looks like it could be an instance method, it has to be a class
  # method for QueuedEmails that come out of the database to work.  See queued_emails.rb
  # for more details.
  def self.deliver_email(email)
    name = nil
    (name_id, old_version, new_version, review_status) =
      email.get_integers([:name, :old_version, :new_version, :review_status])
    name = Name.find(name_id) if name_id
    review_status = review_status < 0 ? nil : Name.all_review_statuses[review_status]
    if !name
      print "No name found for email ##{email.id}.\n"
    elsif email.user == email.to_user
      print "Skipping email with same sender and recipient: #{email.user.email}\n"
    else
      AccountMailer.deliver_name_change(email.user, email.to_user, email.queued,
                                        name, old_version, new_version, review_status)
    end
  end
end
