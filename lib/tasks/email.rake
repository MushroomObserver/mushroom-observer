# frozen_string_literal: true

namespace :email do
  desc "List queued emails"
  task(list: :environment) do
    print "#{MO.http_domain}, #{Rails.env}\n"
    QueuedEmail.all.includes(:queued_email_integers,
                             :queued_email_note,
                             :queued_email_strings, :user).each(&:dump)
  end

  desc "Send queued emails"
  task(send: :environment) do
    # disable cop; `require` needs a String, not a PathName
    require "#{Rails.root}/app/extensions/extensions.rb" # rubocop:disable Rails/FilePath
    count = 0
    # for e in QueuedEmail.find(:all) # Rails 3
    QueuedEmail.all.each do |e|
      now = Time.zone.now()
      # Has it been queued (and unchanged) for MO.email_queue_delay or more.
      if e.queued + MO.email_queue_delay.seconds < now

        # Sent successfully.  (Delete it without sending if user isn't local!
        # This shouldn't happen, but just in case, better safe...)
        if e.to_user
          result = nil
          Rails.root.join("log/email-low-level.log").open("a") do |fh|
            fh.puts("sending #{e.id.inspect}...")
            result = e.send_email
            fh.puts(
              "sent #{e.id.inspect} = #{result ? result.class.name : "false"}"
            )
          end

          # Destroy if sent successfully.
          if result
            e.destroy
            count += 1

          # After a few tries give up and delete it.
          elsif e.num_attempts && (e.num_attempts >= MO.email_num_attempts - 1)
            File.open(MO.email_log, "a") do |fh|
              fh.puts(format("Failed to send email #%d at %s", e.id, now))
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
        else
          e.destroy
          count += 1

        end
      end
    end
  end

  desc "Purge the email queue without sending anything"
  task(purge: :environment) do
    QueuedEmail.all.each do |e|
      print("Purging #{e.id}: from => #{e&.user&.login}, " \
            "to => #{e.to_user.login}, flavor => #{e.flavor}, " \
            "queued => #{e.queued}\n")
      e.destroy
    end
  end
end
