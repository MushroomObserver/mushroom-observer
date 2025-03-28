# frozen_string_literal: true

# Note this gets a params[:user_id] but we're ignoring it here
class Autocomplete::ForHerbarium < Autocomplete::ByWord
  def rough_matches(letter)
    herbaria =
      Herbarium.select(:code, :name, :id).distinct.
      where(Herbarium[:name].matches("#{letter}%").
        or(Herbarium[:name].matches("% #{letter}%")).
        or(Herbarium[:code].matches("#{letter}%"))).
      order(
        Arel.when(Herbarium[:code].is_null).then(Herbarium[:name]).
             else(Herbarium[:code]).asc, Herbarium[:name].asc
      )

    matches_array(herbaria)
  end

  def exact_match(string)
    herbarium = Herbarium.select(:code, :name, :id).distinct.
                where(Herbarium[:name].eq(string)).first
    return [] unless herbarium

    matches_array([herbarium])
  end

  def matches_array(herbaria)
    # Turn the instances into hashes, and figure out what name to display
    matches = herbaria.map do |herbarium|
      herbarium = herbarium.attributes.symbolize_keys
      herbarium[:name] = if herbarium[:code].blank?
                           herbarium[:name]
                         else
                           "#{herbarium[:code]} - #{herbarium[:name]}"
                         end
      herbarium.delete(:code) # faster than `except`
      herbarium
    end
    matches.sort_by! { |herb| herb[:name] }
  end
end
