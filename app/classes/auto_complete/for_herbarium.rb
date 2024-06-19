# frozen_string_literal: true

# Note this gets a params[:user_id] but we're ignoring it here
class AutoComplete::ForHerbarium < AutoComplete::ByWord
  def rough_matches(letter)
    herbaria =
      Herbarium.select(:code, :name).distinct.
      where(Herbarium[:name].matches("#{letter}%").
        or(Herbarium[:name].matches("% #{letter}%")).
        or(Herbarium[:code].matches("#{letter}%"))).
      order(
        Arel.when(Herbarium[:code].is_null).then(Herbarium[:name]).
             else(Herbarium[:code]).asc, Herbarium[:name].asc
      ).pluck(:code, :name, :id)

    herbaria.map do |code, name, id|
      composed_name = code.empty? ? name : "#{code} - #{name}"
      [composed_name, id]
    end.sort_by(&:first).uniq
  end
end
