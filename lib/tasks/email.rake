namespace :email do
  desc "List queued emails"
  task(list: :environment) do
    print "#{MO.http_domain}, #{::Rails.env}\n"
    # for e in QueuedEmail.find(:all, :include => [ # Rails 3
    #  :queued_email_integers, :queued_email_note, :queued_email_strings, :user])
    for e in QueuedEmail.all.includes(:queued_email_integers,
                                      :queued_email_note,
                                      :queued_email_strings, :user)
      e.dump
    end
  end

  desc "Send queued emails"
  task(send: :environment) do
    require "#{::Rails.root}/app/extensions/extensions.rb"
    count = 0
    # for e in QueuedEmail.find(:all) # Rails 3
    for e in QueuedEmail.all
      now = Time.now()
      # Has it been queued (and unchanged) for MO.email_queue_delay or more.
      if e.queued + MO.email_queue_delay.seconds < now

        # Sent successfully.  (Delete it without sending if user isn't local!
        # This shouldn't happen, but just in case, better safe...)
        if !e.to_user
          e.destroy
          count += 1
          if count >= MO.email_per_minute
            # break
          end

        else
          result = nil
          File.open("#{::Rails.root}/log/email-low-level.log", "a") do |fh|
            fh.puts("sending #{e.id.inspect}...")
            result = e.send_email
            fh.puts("sent #{e.id.inspect} = #{result ? result.class.name : "false"}")
          end

          # Destroy if sent successfully.
          if result
            e.destroy
            count += 1
            if count >= MO.email_per_minute
              # break
            end

          # After a few tries give up and delete it.
          elsif e.num_attempts && (e.num_attempts >= MO.email_num_attempts - 1)
            File.open(MO.email_log, "a") do |fh|
              fh.puts("Failed to send email #%d at %s" % [e.id, now])
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
  end

  desc "Purge the email queue without sending anything"
  task(purge: :environment) do
    for e in QueuedEmail.all
      print "Purging #{e.id}: from => #{e&.user&.login}, "\
            "to => #{e.to_user.login}, flavor => #{e.flavor}, "\
            "queued => #{e.queued}\n"
      e.destroy
    end
  end
end
