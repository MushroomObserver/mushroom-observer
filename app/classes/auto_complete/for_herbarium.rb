# frozen_string_literal: true

# Note this gets a params[:user_id] but we're ignoring it here
class AutoComplete::ForHerbarium < AutoComplete::ByWord
  def rough_matches(letter)
    herbaria =
      Herbarium.select(:code, :name, :id).distinct.
      where(Herbarium[:name].matches("#{letter}%").
        or(Herbarium[:name].matches("% #{letter}%")).
        or(Herbarium[:code].matches("#{letter}%"))).
      order(
        Arel.when(Herbarium[:code].is_null).then(Herbarium[:name]).
             else(Herbarium[:code]).asc, Herbarium[:name].asc
      ).pluck(:code, :name, :id)

    herbaria.map! do |code, name, id|
      { name: code.empty? ? name : "#{code} - #{name}", id: id }
    end
    herbaria.sort_by! { |herb| herb[:name] }
  end
end
