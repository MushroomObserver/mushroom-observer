# frozen_string_literal: true

workers Integer(ENV["WEB_CONCURRENCY"] || 2)
threads_count = Integer(ENV["MAX_THREADS"] || 4)
threads threads_count, threads_count

preload_app!

rackup          DefaultRackup
port            ENV["PORT"]     || 3000
environment     ENV["RACK_ENV"] || "production"
redirect_stderr "#{APP_PATH}/log/puma.stderr.log"
redirect_stdout "#{APP_PATH}/log/puma.stdout.log"

on_worker_boot do
  ActiveRecord::Base.establish_connection
end

