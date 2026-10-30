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

    # `deliver_later_queue_name` defaults to nil since Rails 6.1 --
    # ActiveJob::QueueName#queue_name_from_part then falls back to
    # ActiveJob::Base.default_queue_name, matching what
    # ActionMailer::MailDeliveryJob's queue_as block resolves to.
    mailer_queue =
      (ActionMailer::Base.deliver_later_queue_name ||
       ActiveJob::Base.default_queue_name).to_s
    assert_includes(configured_worker_queues, mailer_queue,
                    "No worker in config/queue.yml listens to the " \
                    "ActionMailer deliver_later queue " \
                    "(#{mailer_queue.inspect}) - mail sent via " \
                    "deliver_later would never send in production")
  end

  # SolidQueue::Configuration#valid? reflects only `errors`. An
  # undersized config/database.yml connection pool for
  # config/queue.yml's configured worker threads surfaces in
  # `warnings` instead -- SolidQueue::Supervisor.start logs those but
  # boots anyway -- so this test checks both. Nothing in the app
  # raises on this at boot; it only surfaces when something asks
  # Solid Queue to validate its configuration, which is what this
  # test does.
  def test_database_pool_is_large_enough_for_configured_worker_threads
    config = SolidQueue::Configuration.new
    valid = config.valid?

    # rubocop:disable Minitest/AssertWithExpectedArgument -- the
    # second arg is a failure message, not an expected value.
    assert(valid, config.errors.full_messages.join(", "))
    # rubocop:enable Minitest/AssertWithExpectedArgument
    assert_empty(config.warnings.full_messages,
                 "Solid Queue configuration warning(s) - see " \
                 "config/queue.yml and config/database.yml")
  end

  # test_database_pool_is_large_enough_for_configured_worker_threads only
  # checks the pool for RAILS_ENV, which is always "test" here -- it can't
  # catch a template whose development/production pool is too small for
  # config/queue.yml's workers (the exact gap that let a Solid Queue
  # supervisor boot crash slip through: the "test" pool got fixed to 10,
  # "development" didn't, until the alerts queue in #5416 pushed it over).
  def test_db_templates_development_pool_matches_test_pool
    test_pool = db_template_pool("db/ubuntu/database.yml", "test")

    %w[db/macos/database.yml db/docker/database.yml
       db/ubuntu/database.yml].each do |path|
      dev_pool = db_template_pool(path, "development")
      assert(dev_pool && dev_pool >= test_pool,
             "#{path}'s development.primary.pool (#{dev_pool.inspect}) " \
             "must be at least as large as its test pool " \
             "(#{test_pool.inspect}) -- both run the same " \
             "config/queue.yml workers")
    end
  end

  private

  def db_template_pool(relative_path, env)
    rendered = ERB.new(Rails.root.join(relative_path).read).result
    config = YAML.safe_load(rendered, aliases: true)
    (config.dig(env, "primary", "pool") || config.dig(env, "pool"))&.to_i
  end

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
