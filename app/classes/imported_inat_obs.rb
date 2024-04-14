# frozen_string_literal: true

# Represents the result of an iNat API observation search for one observation
class ImportedInatObs
  def initialize(imported_inat_obs_data)
    @imported_inat_obs_data =
      JSON.parse(imported_inat_obs_data, symbolize_names: true)
  end

  def obs
    @imported_inat_obs_data[:results].first
  end

  def when
    observed_on = obs[:observed_on_details]
    Date.new(observed_on[:year], observed_on[:month], observed_on[:day])
  end

  def where
    obs[:place_guess]
  end
end
