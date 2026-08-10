# frozen_string_literal: true

module Observations
  # The observation-scoped scan page: every photo with its scan state
  # -- a Read Field Slip button when unscanned, a link to the photo's
  # review or status page otherwise. This is where the no-slip-detected
  # flash lands (choosing which photo shows the slip is a decision
  # about the observation, not any one image), and the way back to
  # scanning later; #5041 links it from the field slip show page.
  class FieldSlipScansController < ApplicationController
    before_action :login_required
    before_action :find_observation!
    before_action :permission_required

    def show
      render(Views::Controllers::Observations::FieldSlipScans::Show.new(
               observation: @observation, user: @user
             ))
    end

    private

    def find_observation!
      @observation = Observation.safe_find(params[:id])
      return @observation if @observation

      flash_error(:runtime_object_not_found.t(type: :observation,
                                              id: params[:id]))
      redirect_to(observations_path)
      nil
    end

    # Same gate as the per-image extract pages: site admins and admins
    # of any project the observation belongs to (each scan costs an
    # API call). A `before_action` halts the chain when it redirects.
    def permission_required
      return unless @observation
      return if in_admin_mode?
      return if @observation.projects.any? do |project|
        project.is_admin?(@user)
      end

      flash_error(:permission_denied.t)
      redirect_to(permanent_observation_path(@observation.id))
    end
  end
end
