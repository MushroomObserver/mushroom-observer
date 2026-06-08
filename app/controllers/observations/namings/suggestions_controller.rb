# frozen_string_literal: true

# Generates suggested namings from ML
module Observations::Namings
  class SuggestionsController < ApplicationController
    before_action :login_required

    def show
      @observation = load_for_show_observation_or_goto_index(params[:id])
      return unless @observation

      @suggestions = Suggestion.analyze(JSON.parse(params[:names].to_s))
      render(Views::Controllers::Observations::Namings::Suggestions::Show.new(
               observation: @observation, user: @user,
               suggestions: @suggestions
             ))
    end
  end
end
