# frozen_string_literal: true

# Note this gets a params[:user_id] but we're ignoring it here
class AutoCompleteHerbarium < AutoCompleteByWord
  def rough_matches(letter)
    herbaria =
      Herbarium.select(:code, :name).distinct.
      where(Herbarium[:name].matches("#{letter}%").
        or(Herbarium[:name].matches("% #{letter}%")).
        or(Herbarium[:code].matches("#{letter}%"))).
      order(
        Arel.when(Herbarium[:code].is_null).then(Herbarium[:name]).
             else(Herbarium[:code]).asc, Herbarium[:name].asc
      ).pluck(:code, :name)

    herbaria.map do |code, name|
      code.empty? ? name : "#{code} - #{name}"
    end.sort
  end
end
