# frozen_string_literal: true

# see observer_controller.rb
module ObserverController::Suggestions
  def suggestions
    @observation = load_for_show_observation_or_goto_index(params[:id])
    @suggestions = Suggestion.analyze(JSON.parse(params[:names].to_s))
  end
end
