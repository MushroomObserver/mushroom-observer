namespace :email do
  desc "List queued emails"
  task(:list => :environment) do
    print "#{DOMAIN}\n"
    for e in QueuedEmail.find(:all, :include => [
      :queued_email_integers, :queued_email_note, :queued_email_strings, :user])
      print "#{e.id}: from => #{e.user.login}, to => #{e.to_user.login}, flavor => #{e.flavor}, queued => #{e.queued}\n"
      for i in e.queued_email_integers
        print "\t#{i.key.to_s} => #{i.value}\n"
      end
      for i in e.queued_email_strings
        print "\t#{i.key.to_s} => #{i.value}\n"
      end
      if e.queued_email_note
        print "\tNote: #{e.queued_email_note.value}\n"
      end
    end
  end

  desc "Send queued emails"
  task(:send => :environment) do
    count = 0
    for e in QueuedEmail.find(:all)
      if e.queued + QUEUE_DELAY < Time.now() # Has it been queued (and unchanged) for QUEUE_DELAY or more
        if e.send_email
          e.destroy
          count += 1
          if count >= EMAIL_PER_MINUTE
            break
          end
        end
      end
    end
    print "Sent #{count} email(s)\n"
  end
  
  desc "Purge the email queue without sending anything"
  task(:purge => :environment) do
    for e in QueuedEmail.find(:all)
      print "Purging #{e.id}: from => #{e.user.login}, to => #{e.to_user.login}, flavor => #{e.flavor}, queued => #{e.queued}\n"
      e.destroy
    end
  end
end
