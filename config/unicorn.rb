APP_PATH = "/var/web/mo"
worker_processes 3
working_directory APP_PATH
listen APP_PATH + "/tmp/sockets/unicorn.sock", backlog: 64
listen 8080, tcp_nopush: true
timeout 300
pid APP_PATH + "/tmp/pids/unicorn.pid"
stderr_path APP_PATH + "/log/unicorn.stderr.log"
stdout_path APP_PATH + "/log/unicorn.stdout.log"
preload_app false
GC.respond_to?(:copy_on_write_friendly=) and
  GC.copy_on_write_friendly = true
check_client_connection false
before_fork do |_server, _worker|
  defined?(ActiveRecord::Base) &&
    ActiveRecord::Base.connection.disconnect!
end
after_fork do |_server, _worker|
  defined?(ActiveRecord::Base) &&
    ActiveRecord::Base.establish_connection
end
