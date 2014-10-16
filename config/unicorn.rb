APP_PATH = '/var/web/mo'
worker_processes 4
working_directory APP_PATH
listen APP_PATH + '/tmp/.unicorn.sock', :backlog => 64
listen 8080, :tcp_nopush => true
timeout 300
pid APP_PATH + '/tmp/unicorn.pid'
stderr_path APP_PATH + '/log/unicorn.stderr.log'
stdout_path APP_PATH + '/log/unicorn.stdout.log'
preload_app false
GC.respond_to?(:copy_on_write_friendly=) and
  GC.copy_on_write_friendly = true
check_client_connection false
before_fork do |server, worker|
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!
end
after_fork do |server, worker|
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection
end
