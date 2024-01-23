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

    #########

    private

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id].to_s)
    end
  end
end
