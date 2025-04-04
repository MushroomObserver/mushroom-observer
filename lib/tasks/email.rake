# frozen_string_literal: true

namespace :email do
  desc "List queued emails"
  task(list: :environment) do
    print "#{MO.http_domain}, #{Rails.env}\n"
    QueuedEmail.includes(:queued_email_integers,
                         :queued_email_note,
                         :queued_email_strings, :user).
      find_each(&:dump)
  end

  desc "Send queued emails"
  task(send: :environment) do
    count = 0
    QueuedEmail.find_each do |e|
      now = Time.zone.now
      # Has it been queued (and unchanged) for MO.email_queue_delay or more.
      next unless e.queued + MO.email_queue_delay.seconds < now

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
    end
  end

  desc "Purge the email queue without sending anything"
  task(purge: :environment) do
    QueuedEmail.find_each do |e|
      print("Purging #{e.id}: from => #{e&.user&.login}, " \
            "to => #{e.to_user.login}, flavor => #{e.flavor}, " \
            "queued => #{e.queued}\n")
      e.destroy
    end
  end
end
