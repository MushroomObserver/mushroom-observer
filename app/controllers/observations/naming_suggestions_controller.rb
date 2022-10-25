# frozen_string_literal: true

# see observations_controller.rb
module Observations
  class NamingSuggestionsController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    def show
      @observation = load_for_show_observation_or_goto_index(params[:id])
      @suggestions = Suggestion.analyze(JSON.parse(params[:names].to_s))
    end
  end
end
