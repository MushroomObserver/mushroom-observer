# frozen_string_literal: true

require("test_helper")

# Regression guard for the bug Copilot caught on PR #4727: config/queue.yml
# restricting workers to specific queues can silently starve a queue nobody
# declared a worker for - e.g. ActionMailer's deliver_later jobs (queue
# "mailers" by default) went unclaimed until a worker was added for it.
class QueueConfigTest < UnitTestCase
  def test_every_job_queue_is_covered_by_a_worker
    skip if all_queues_covered?

    job_queue_names.each do |queue|
      assert_includes(configured_worker_queues, queue,
                      "No worker in config/queue.yml listens to queue " \
                      "#{queue.inspect} - jobs on it would never run")
    end
  end

  def test_actionmailer_deliver_later_queue_is_covered_by_a_worker
    skip if all_queues_covered?

    mailer_queue = ActionMailer::Base.deliver_later_queue_name.to_s
    assert_includes(configured_worker_queues, mailer_queue,
                    "No worker in config/queue.yml listens to the " \
                    "ActionMailer deliver_later queue " \
                    "(#{mailer_queue.inspect}) - mail sent via " \
                    "deliver_later would never send in production")
  end

  # Regression guard for the incident on 2026-07-09: config/queue.yml's
  # busiest worker pool needed more threads than config/database.yml's
  # connection pool had, so Solid Queue's own startup validation
  # (SolidQueue::Configuration#ensure_correctly_sized_thread_pool) failed
  # every single time the supervisor (re)started, crash-looping forever --
  # no queue, including "mailers", was ever claimed again after that.
  # Nothing in the app raises on this at boot; it only surfaces if
  # something actually asks Solid Queue to validate its own configuration,
  # which is exactly what this test does.
  def test_database_pool_is_large_enough_for_configured_worker_threads
    config = SolidQueue::Configuration.new
    valid = config.valid?

    # config.error_messages is a failure MESSAGE (already a String), not
    # an expected value -- assert_equal(valid, config.error_messages)
    # (what the cop suggests, and what a prior Copilot-suggested edit
    # actually shipped) compares a boolean against a String and can
    # never pass.
    # rubocop:disable Minitest/AssertWithExpectedArgument
    assert(valid, config.error_messages)
    # rubocop:enable Minitest/AssertWithExpectedArgument
  end

  private

  def all_queues_covered?
    configured_worker_queues.include?("*")
  end

  def configured_worker_queues
    return @configured_worker_queues if @configured_worker_queues

    path = Rails.root.join("config/queue.yml")
    workers = YAML.load_file(path, aliases: true)["production"]["workers"]
    @configured_worker_queues = workers.flat_map { |w| Array(w["queues"]) }
  end

  def job_queue_names
    Rails.root.glob("app/jobs/*.rb").filter_map do |path|
      match = File.read(path).match(/queue_as[\s(]*[:'"](\w+)/)
      match && match[1]
    end.uniq
  end
end
