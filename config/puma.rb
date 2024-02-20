# frozen_string_literal: true

workers Integer(ENV["WEB_CONCURRENCY"] || 2)
threads_count = Integer(ENV["MAX_THREADS"] || 5)
threads threads_count, threads_count

# preload_app!
prune_bundler

directory           APP_PATH
rackup              DefaultRackup
port                ENV["PORT"]     || 3000
environment         ENV["RACK_ENV"] || "production"
redirect_stderr     "#{APP_PATH}/log/puma.stderr.log"
redirect_stdout     "#{APP_PATH}/log/puma.stdout.log"
bind                "#{APP_PATH}/tmp/sockets/puma.sock"
pidfile             "#{APP_PATH}/tmp/pids/puma.pid"

# on_worker_boot do
#   ActiveRecord::Base.establish_connection
# end

