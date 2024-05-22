# frozen_string_literal: true

# Encapsulates the result of an iNat API search for one observation,
# mapping iNat key/values to MO Observation attributes
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

  def inat_id
    obs[:id]
  end

  def license
    InatLicense.new(obs[:license_code]).license
  end

  def obs_photos
    obs[:observation_photos]
  end

  def name_id
    inat_taxon = obs[:taxon]
    mo_names = Name.where(text_name: inat_taxon[:name],
                          rank: inat_taxon[:rank].titleize).
               # iNat doesn't have names "sensu xxx"
               # so don't map them to MO Names sensu xxx
               where.not(Name[:author] =~ /^sensu /)
    return Name.unknown.id if mo_names.none?
    return mo_names.first.id if mo_names.one?

    # iNat name maps to multiple MO Names
    # So for the moment, just map it to Fungi
    # TODO: refine this.
    # Ideas: check iNat and MO authors, possibly prefer non-deprecated MO Name
    # - might need a dictionary here
    Name.unknown.id
  end

  def notes
    return "" if description.empty?

    { Other: description.gsub(%r{</?p>}, "") }
  end

  # :location seems simplest source for lat/lng
  # But [:geojason] might be possible.
  def lat
    obs[:location].split(",").first.to_f
  end

  def lng
    obs[:location].split(",").second.to_f
  end

  def text_name
    Name.find(name_id).text_name
  end

  def when
    observed_on = obs[:observed_on_details]
    Date.new(observed_on[:year], observed_on[:month], observed_on[:day])
  end

  def where
    obs[:place_guess]
  end


  ##########

  private

  def description
    obs[:description]
  end
end
