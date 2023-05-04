# frozen_string_literal: true

# Remove one observation from a collection number.
#
# Route: `collection_number_remove_observation_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/collection_numbers/remove_observation", action: :update }`
module CollectionNumbers
  class RemoveObservationsController < ApplicationController
    before_action :login_required

    def update
      pass_query_params
      @collection_number = find_or_goto_index(CollectionNumber,
                                              params[:collection_number_id])
      return unless @collection_number

      @observation = find_or_goto_index(Observation, params[:observation_id])
      return unless @observation

      return unless make_sure_can_delete!(@collection_number)

      @collection_number.remove_observation(@observation)
      respond_to do |format|
        format.html do
          redirect_with_query(observation_path(@observation.id))
        end
        format.js do
          render(partial: "collection_numbers/update_observation") and return
        end
      end
    end

    private

    def make_sure_can_delete!(collection_number)
      return true if collection_number.can_edit? || in_admin_mode?

      flash_error(:permission_denied.t)
      redirect_to(collection_number_path(collection_number))
      false
    end
  end
end
