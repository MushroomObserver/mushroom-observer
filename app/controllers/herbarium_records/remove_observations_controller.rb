# frozen_string_literal: true

# Remove one observation from a herbarium record.
#
# Route: `herbarium_record_remove_observation_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "herbarium_records/remove_observation", action: :update }`
module HerbariumRecords
  class RemoveObservationsController < ApplicationController
    before_action :login_required

    def update
      pass_query_params
      @herbarium_record = find_or_goto_index(HerbariumRecord,
                                             params[:herbarium_record_id])
      return unless @herbarium_record

      @observation = find_or_goto_index(Observation, params[:observation_id])
      return unless @observation

      return unless make_sure_can_delete!(@herbarium_record)

      @herbarium_record.remove_observation(@observation)
      flash_notice(:runtime_removed.t(type: :herbarium_record))

      respond_to do |format|
        format.html do
          redirect_with_query(observation_path(@observation.id))
        end
        format.js do
          render(
            partial: "observations/show/section_update",
            locals: { identifier: "herbarium_records" }
          ) and return
        end
      end
    end

    private

    def make_sure_can_delete!(herbarium_record)
      return true if herbarium_record.can_edit? || in_admin_mode?
      return true if herbarium_record.herbarium.curator?(@user)

      flash_error(:permission_denied.t)
      redirect_to(herbarium_record_path(herbarium_record))
      false
    end
  end
end
