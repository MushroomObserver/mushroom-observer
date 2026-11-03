# frozen_string_literal: true

# Generates suggested namings from ML
module Observations::Namings
  class SuggestionsController < ApplicationController
    before_action :login_required

    def show
      @observation = load_for_show_observation_or_goto_index(params[:id])
      return unless @observation

      names = parsed_names
      return redirect_to(permanent_observation_path(@observation)) unless
        names

      @suggestions = Suggestion.analyze(names)
      render(Views::Controllers::Observations::Namings::Suggestions::Show.new(
               observation: @observation, user: @user,
               suggestions: @suggestions
             ))
    end

    private

    # `names` is JS-supplied JSON from the image classifier (see
    # footer_buttons.rb) -- blank, malformed, or non-Array JSON here
    # means a direct or stale request, not a classifier result.
    # Suggestion.analyze requires an Array, so valid-but-wrong-shaped
    # JSON (null, {}, false, a bare number) must be rejected too, not
    # just a JSON::ParserError.
    def parsed_names
      data = JSON.parse(params[:names].to_s)
      data if data.is_a?(Array)
    rescue JSON::ParserError
      nil
    end
  end
end
