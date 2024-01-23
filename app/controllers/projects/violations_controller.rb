# frozen_string_literal: true

#  ==== Manage Project Constraint Violations

module Projects
  # CRUD for project violations
  class ViolationsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    def index
      return unless find_project!
    end
  end
end
