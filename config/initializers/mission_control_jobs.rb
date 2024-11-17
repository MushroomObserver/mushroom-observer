# frozen_string_literal: true

# Limit /jobs to admins
# https://github.com/rails/mission_control-jobs?tab=readme-ov-file#authentication-and-base-controller-class
Rails.application.configure do
  MissionControl::Jobs.base_controller_class = "AdminController"
end
