# frozen_string_literal: true

module Observations
  # Turbo Frame content for the observation show page's "About this
  # Taxon" panel (#5093). The panel starts collapsed with an empty
  # placeholder frame; expanding it sends a real GET carrying a
  # `Turbo-Frame` request header, fetched here instead of eager-loading
  # the name subtree (synonyms/descriptions/interests) on every
  # observation page view. A direct (non-frame) visit falls back to
  # redirecting to the observation instead of rendering a bare fragment.
  class NameInfoPanelsController < ApplicationController
    before_action :login_required
    before_action :find_observation!

    # `Descriptions::List#visible?` reads each description's `.user`,
    # so `descriptions: :user` avoids N+1 per description in the panel.
    # This subtree used to live in `Observation.show_includes_tree` --
    # moved here since this frame is now its only consumer.
    NAME_INCLUDES = {
      name: [{ synonym: :names }, { descriptions: :user },
             :interests, :description]
    }.freeze

    def show
      if request.headers["Turbo-Frame"]
        render(Views::Controllers::Observations::NameInfoPanels::Show.new(
                 obs: @observation, user: @user
               ), layout: false)
      else
        redirect_to(permanent_observation_path(@observation))
      end
    end

    private

    def find_observation!
      @observation = Observation.includes(NAME_INCLUDES).
                     safe_find(params[:id])
      return @observation if @observation

      flash_error(:runtime_object_not_found.t(type: :observation,
                                              id: params[:id]))
      redirect_to(observations_path)
      nil
    end
  end
end
