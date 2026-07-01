# frozen_string_literal: true

# Resume SolidQueue after a restart / deploy: remove every queue pause created
# by script/pause_and_drain_jobs.rb so workers start claiming jobs again.
# Queued-but-unclaimed jobs (including anything enqueued while paused) run now.
#
# Usage: bundle exec rails runner script/resume_jobs.rb

paused = SolidQueue::Pause.pluck(:queue_name)

if paused.empty?
  puts("No paused queues; nothing to resume.")
else
  paused.each do |name|
    SolidQueue::Queue.find_by_name(name).resume
    puts("Resumed queue: #{name}")
  end
end
