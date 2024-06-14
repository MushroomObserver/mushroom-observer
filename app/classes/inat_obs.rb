# frozen_string_literal: true

#
#  = InatObs Object
#
#  Represents the result of an iNat API search for one observation,
#  mapping iNat key/values to MO Observation attributes
#
#  == Class methods
##
#  == Instance methods
#
#  obs::          The iNat observation data
#  obs_photos::   Array of iNat observation_photos
#  importable?::  Is it importable to MO?
#  fungi?::       Is it a fungus?
#  inat_user_login
#
#  == MO attributes
#  gps_hidden
#  inat_id::
#  license::
#  name_id
#  notes
#  lat
#  lng
#  text_name
#  when
#  where
#
class InatObs
  def initialize(imported_inat_obs_data)
    @imported_inat_obs_data =
      JSON.parse(imported_inat_obs_data, symbolize_names: true)
  end

  def obs
    @imported_inat_obs_data[:results].first
  end

  def obs_photos
    obs[:observation_photos]
  end

  def importable?
    taxon_importable?
  end

  def taxon_importable?
    fungi? || slime_mold?
  end

  def inat_location
    obs[:location]
  end

  def inat_place_guess
    obs[:place_guess]
  end

  # comma-separated string of names of projects to which obs belongs
  def inat_project_names
    projects = inat_projects

    # 2024-06-12 jdc
    # 1. Stop inat_obs from returning the following when projects.empty
    # # encoding: US-ASCII
    # #    valid: true
    # ""
    #
    # 2. Always include ?? because I cannot reliably find all the projects
    # via the iNat API
    return "??" if projects.empty?

    # Extract the titles from each project observation
    (projects.map { |proj| proj.dig(:project, :title) } << "??").
      join(", ").delete_prefix(", ")
  end

  def inat_public_positional_accuracy
    obs[:public_positional_accuracy]
  end

  def inat_quality_grade
    obs[:quality_grade]
  end

  def inat_taxon_name
    obs[:taxon][:name]
  end

  def inat_user_login
    obs[:user][:login]
  end

  ########## MO attributes

  def gps_hidden
    obs[:geoprivacy].present?
  end

  def inat_id
    obs[:id]
  end

  def license
    InatLicense.new(obs[:license_code]).mo_license
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
    inat_location.split(",").first.to_f
  end

  def lng
    inat_location.split(",").second.to_f
  end

  def text_name
    Name.find(name_id).text_name
  end

  def when
    observed_on = obs[:observed_on_details]
    Date.new(observed_on[:year], observed_on[:month], observed_on[:day])
  end

  def where
    # FIXME: Make it a real MO Location
    # Maybe smallest existing MO Location containing:
    #   inat.location +/- inat.positional accuracy
    inat_place_guess
  end

  ##########

  private

  def description
    obs[:description]
  end

  def fungi?
    obs.dig(:taxon, :iconic_taxon_name) == "Fungi"
  end

  # TODO: 2024-06-13 jdc. This is unreliable.
  # Is there a better way?
  # See https://github.com/MushroomObserver/mushroom-observer/issues/1955#issuecomment-2164323992
  def inat_projects
    obs[:project_observations]
  end

  def slime_mold?
    # NOTE: 2024-06-01 jdc
    # slime molds are polypheletic https://en.wikipedia.org/wiki/Slime_mold
    # Protoza is paraphyletic for slime molds,
    # but it's how they are classified in MO and MB
    # Can this be improved by checking multiple inat [:taxon][:ancestor_ids]?
    # I.e., is there A combination (ANDs) of higher ranks (>= Class)
    # that's monophyletic for slime molds?
    # Another solution: use IF API to see if IF includes the name.
    obs.dig(:taxon, :iconic_taxon_name) == "Protozoa"
  end
end
