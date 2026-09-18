# frozen_string_literal: true

rails_env = ENV.fetch("RAILS_ENV", "development")

case rails_env
when "development"
  app_path = ENV.fetch("PWD", ".")
  port(3000)
  workers(0)
  threads(1, 1)
when "test"
  app_path = ENV.fetch("PWD", ".")
  workers(0)
  threads(1, 1)
when "production"
  # Total concurrency = workers x threads. Workers are the safe lever:
  # the app has always run single-threaded in production, so raise
  # RAILS_MAX_THREADS only as a deliberate, tested change (and size
  # database.yml's pool to match).
  workers(Integer(ENV.fetch("WEB_CONCURRENCY", 6)))
  max_threads = Integer(ENV.fetch("RAILS_MAX_THREADS", 1))
  threads(max_threads, max_threads)

  if ENV["PORT"]
    # Running under Docker/Kamal (#5345) -- the proxy reaches the
    # container over the network, not a shared filesystem socket, and
    # Docker's restart policy tracks the process, not a pidfile. Both
    # Puma's process output and the Rails app logger (see
    # config/environments/production.rb) go to STDOUT here, captured
    # by `docker logs`/Kamal.
    app_path = ENV.fetch("PWD", ".")
    bind("tcp://0.0.0.0:#{ENV.fetch("PORT")}")
  else
    app_path = "/var/web/mushroom-observer"
    bind("unix://#{app_path}/tmp/sockets/puma.sock")
    stdout_redirect("#{app_path}/log/puma.stdout.log",
                    "#{app_path}/log/puma.stderr.log", true)
  end
end

environment rails_env

unless rails_env == "production" && ENV["PORT"]
  pidfile    "#{app_path}/tmp/pids/puma.pid"
  state_path "#{app_path}/tmp/pids/puma.state"
end

# To run Solid Queue's supervisor together with Puma and have Puma monitor
# and manage it. With this you don't have to `bin/rails solid_queue:start`,
# but there's a lot of queue chatter in the console, even when debugging.
# https://github.com/rails/solid_queue?tab=readme-ov-file#puma-plugin
#
# Not in production: there the dedicated solidqueue.service is the sole
# supervisor. Running the plugin there too would start a second supervisor
# that also claims jobs, doubling the worker footprint and complicating
# the deploy lifecycle (see issue #4639).
plugin :solid_queue unless rails_env == "production"

activate_control_app

if rails_env == "production"
  on_worker_boot do
    # Clear ALL connection pools (primary, cache, etc.) after fork.
    # Without this, forked workers inherit connections whose Trilogy
    # @owner thread no longer matches Thread.current, causing
    # Trilogy::SynchronizationError when SolidCache's background
    # expiry thread tries to use the inherited cache connection.
    # Surfaced by Trilogy 2.11.0 which now raises explicitly on
    # concurrent connection use (previously silent/undefined behavior).
    ActiveRecord::Base.connection_handler.clear_all_connections!
  end
end
