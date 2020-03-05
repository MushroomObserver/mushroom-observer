module SuggestionsHelper
  def suggestion_confidence(val)
    english = if val > 80
                :suggestions_excellent.t
              elsif val > 50
                :suggestions_good.t
              elsif val > 25
                :suggestions_fair.t
              else
                :suggestions_poor.t
              end
    "#{val.round(2)}% (" + english + ")"
  end
end
