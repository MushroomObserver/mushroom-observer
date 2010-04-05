namespace :email do
  desc "List queued emails"
  task(:list => :environment) do
    print "#{DOMAIN}, #{RAILS_ENV}\n"
    for e in QueuedEmail.find(:all, :include => [
      :queued_email_integers, :queued_email_note, :queued_email_strings, :user])
      print e.dump()
    end
  end

  desc "Send queued emails"
  task(:send => :environment) do
    count = 0
    for e in QueuedEmail.find(:all)
      now = Time.now()
      if e.queued + QUEUE_DELAY < now # Has it been queued (and unchanged) for QUEUE_DELAY or more

        # Sent successfully.
        if e.send_email
          e.destroy
          count += 1
          if count >= EMAIL_PER_MINUTE
            # break
          end

        # After a few tries give up and delete it.
        elsif e.num_attempts and (e.num_attempts >= EMAIL_NUM_ATTEMPTS - 1)
          File.open(EMAIL_LOG, 'a') do |fh|
            fh.puts('Failed to send email #%d at %s' % [e.id, now])
            fh.puts(e.dump)
          end
          e.destroy

        # Schedule next attempt for 5 minutes later.
        else
          e.queued = now
          if e.num_attempts
            e.num_attempts += 1
          else
            e.num_attempts = 1
          end
          e.save
        end
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
