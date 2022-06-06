# frozen_string_literal: true

# see observer_controller.rb
class ObserverController
  helper SuggestionsHelper
  def suggestions
    @observation = load_for_show_observation_or_goto_index(params[:id])
    @suggestions = Suggestion.analyze(JSON.parse(params[:names].to_s))
  end
end
