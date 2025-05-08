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
  app_path = "/var/web/mushroom-observer"
  bind("unix://#{app_path}/tmp/sockets/puma.sock")
  workers(3)
  threads(1, 1)
  stdout_redirect("#{app_path}/log/puma.stdout.log",
                  "#{app_path}/log/puma.stderr.log", true)
end

environment rails_env
pidfile         "#{app_path}/tmp/pids/puma.pid"
state_path      "#{app_path}/tmp/pids/puma.state"
activate_control_app
plugin :solid_queue

if rails_env == "production"
  on_worker_boot do
    require("active_record")
    begin
      ActiveRecord::Base.connection.disconnect!
    rescue StandardError
      ActiveRecord::ConnectionNotEstablished
    end
    ActiveRecord::Base.establish_connection(
      YAML.load_file("#{app_path}/config/database.yml")[rails_env]["primary"]
    )
  end
end
