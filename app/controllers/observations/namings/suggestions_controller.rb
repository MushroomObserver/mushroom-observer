# frozen_string_literal: true

# Generates suggested namings from ML
module Observations::Namings
  class SuggestionsController < ApplicationController
    before_action :login_required

    def show
      @observation = load_for_show_observation_or_goto_index(params[:id])
      return unless @observation

      names = parsed_names
      return unless names

      @suggestions = Suggestion.analyze(names)
      render(Views::Controllers::Observations::Namings::Suggestions::Show.new(
               observation: @observation, user: @user,
               suggestions: @suggestions
             ))
    end

    private

    # `names` is JS-supplied JSON from the image classifier (see
    # footer_buttons.rb) -- blank or malformed here means a direct or
    # stale request, not a classifier result.
    def parsed_names
      JSON.parse(params[:names].to_s)
    rescue JSON::ParserError
      redirect_to(permanent_observation_path(@observation))
      nil
    end
  end
end
