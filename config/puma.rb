# frozen_string_literal: true

workers 3
threads 1, 1

app_path = "/var/web/mushroom-observer"
rails_env = "production"

environment         rails_env
bind                "unix://#{app_path}/tmp/sockets/puma.sock"
stdout_redirect     "#{app_path}/log/puma.stdout.log",
                    "#{app_path}/log/puma.stderr.log", true
pidfile             "#{app_path}/tmp/pids/puma.pid"
state_path          "#{app_path}/tmp/pids/puma.state"
activate_control_app

# on_worker_boot do
#   require "active_record"
#   ActiveRecord::Base.connection.disconnect! rescue ActiveRecord::ConnectionNotEstablished
#   ActiveRecord::Base.establish_connection(YAML.load_file("#{app_path}/config/database.yml")["production"]["primary"])
# end
