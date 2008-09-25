namespace :email do
  desc "List queued emails"
  task(:list => :environment) do
    print "#{DOMAIN}, #{RAILS_ENV}\n"
    for e in QueuedEmail.find(:all, :include => [
      :queued_email_integers, :queued_email_note, :queued_email_strings, :user])
      e.dump()
    end
  end

  desc "Send queued emails"
  task(:send => :environment) do
    count = 0
    for e in QueuedEmail.find(:all)
      now = Time.now()
      if e.queued + QUEUE_DELAY < now # Has it been queued (and unchanged) for QUEUE_DELAY or more
        if e.send_email
          count += 1
          if count >= EMAIL_PER_MINUTE
            break
          end
        end
        e.destroy # Tried to send it, but it failed
      end
    end
  end
  
  desc "Purge the email queue without sending anything"
  task(:purge => :environment) do
    for e in QueuedEmail.find(:all)
      print "Purging #{e.id}: from => #{e.user and e.user.login}, to => #{e.to_user.login}, flavor => #{e.flavor}, queued => #{e.queued}\n"
      e.destroy
    end
  end
end
