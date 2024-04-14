# frozen_string_literal: true

# Data representing a single iNat observation
# which data is a json hash obtained from the iNat API
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
end
