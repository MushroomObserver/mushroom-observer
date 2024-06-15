# frozen_string_literal: true

class AutoComplete::ForLocationEncompassing < AutoComplete::ByWord
  attr_accessor :reverse

  def initialize(string, params)
    super(string, params)
    self.reverse = (params[:format] == "scientific")
    self.lat = params[:lat]
    self.lng = params[:lng]
  end

  # We don't care about the letter, this list should be short
  # Maybe reject location where box is too large.
  def rough_matches(_letter)
    matches =
      Location.contains(lat: lat, lng: lng).select(:name).distinct.
      # where(Location[:name].matches("#{letter}%").
      #   or(Location[:name].matches("% #{letter}%"))).
      pluck(:name)

    matches.map! { |m| Location.reverse_name(m) } if reverse
    matches.sort.uniq
  end
end
