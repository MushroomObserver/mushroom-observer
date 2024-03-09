# frozen_string_literal: true

# Show and remove non-compliant Observations from a Project
module Projects
  # Actions
  # -------
  # edit (get)
  # update (patch)
  #
  class ViolationsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    def edit
      return unless find_project!

      @violations = @project.violations
    end

    #########

    private

    def find_project!
      @project = find_or_goto_index(Project, params[:id])
    end
  end
end
