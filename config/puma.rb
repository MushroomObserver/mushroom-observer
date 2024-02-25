# frozen_string_literal: true

workers Integer(ENV["WEB_CONCURRENCY"] || 3)
threads_count = Integer(ENV["MAX_THREADS"] || 1)
threads threads_count, threads_count

# preload_app!
prune_bundler

rackup              DefaultRackup if defined?(DefaultRackup)
port                ENV["PORT"]     || 3000
environment         ENV["RAILS_ENV"] || "production"

# directory           "/var/web/mo"
# redirect_stderr     "/var/web/mo/log/puma.stderr.log"
# redirect_stdout     "/var/web/mo/log/puma.stdout.log"
# bind                "/var/web/mo/tmp/sockets/puma.sock"
# pidfile             "/var/web/mo/tmp/pids/puma.pid"

# on_worker_boot do
#   ActiveRecord::Base.establish_connection
# end

