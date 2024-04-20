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

  def gps_hidden
    obs[:geoprivacy].present?
  end

  def name_id
    inat_taxon = obs[:taxon]

    # TODO: refine this.
    # - include rank
    # - might need a dictionary here
    mo_names = Name.where(text_name: inat_taxon[:name],
                          rank: inat_taxon[:rank].titleize)
    return Name.unknown.id if mo_names.none?
    return mo_names.first.id if mo_names.one?

    Name.unknown.id
  end

  def notes
    desc = obs[:description]
    { Other: desc.gsub(%r{</?p>}, "") }
  end

  # :location seems simplest source for lat/lng
  # But [:geojason] might be possible.
  def lat
    obs[:location].split(",").first.to_f
  end

  def lng
    obs[:location].split(",").second.to_f
  end

  def when
    observed_on = obs[:observed_on_details]
    Date.new(observed_on[:year], observed_on[:month], observed_on[:day])
  end

  def where
    obs[:place_guess]
  end
end
