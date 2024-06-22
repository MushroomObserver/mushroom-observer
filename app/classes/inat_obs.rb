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
#  === iNat attributes & associations
#
#  obs::                 The iNat observation data
#  inat_id::
#  inat_location::       lat,lon
#  inat_obs_fields::     array of fields, each field a hash
#  inat_obs_photos::     array of observation_photos
#  inat_place_guess::
#  inat_project_names::
#  inat_public_positional_accuracy:: accuracy of inat_lation in meters
#  inat_quality_grade::  casual, needs id, research
#  inat_tags::           array of tags
#  inat_taxon_name::     scientific name
#  inat_user_login
#
#  == MO attributes
#  gps_hidden
#  license::
#  name_id
#  notes
#  lat
#  lng
#  text_name
#  when
#  where
#
# == Utilties
#
#  importable?::  Is it importable to MO?
#
class InatObs
  def initialize(imported_inat_obs_data)
    @imported_inat_obs_data =
      JSON.parse(imported_inat_obs_data, symbolize_names: true)
  end

  def inat_id
    obs[:id]
  end

  def inat_location
    obs[:location]
  end

  def inat_obs_fields
    obs[:ofvs]
  end

  def inat_obs_photos
    obs[:observation_photos]
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

  def inat_tags
    obs[:tags]
  end

  def inat_taxon_name
    inat_taxon[:name]
  end

  def inat_user_login
    obs[:user][:login]
  end

  ########## MO attributes

  def gps_hidden
    obs[:geoprivacy].present?
  end

  def license
    InatLicense.new(obs[:license_code]).mo_license
  end

  def name_id
    mo_names = Name.where(text_name: inat_taxon[:name],
                          rank: inat_taxon[:rank].titleize).
               # iNat doesn't have taxon names "sensu xxx"
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

  def sequences
    obs_sequence_fields =
      inat_obs_fields.keep_if { |f| sequence_field?(f) }

    obs_sequence_fields.each_with_object([]) do |field, ary|
      # TODO: 2024-06-19 jdc. Need more investigation/test to handle
      # field[:value] blank or not a (pure) lists of bases
      ary << { locus: field[:name], bases: field[:value],
               # NTOE: 2024-06-19 jdc. Can we figure out the following?
               archive: nil, accession: "", notes: "" }
    end
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

  ########## utilties

  def importable?
    taxon_importable?
  end

  def taxon_importable?
    fungi? || slime_mold?
  end

  ##########

  private

  # The data for just one obs (omits metadata about the API request)
  def obs
    @imported_inat_obs_data[:results].first
  end

  def description
    obs[:description]
  end

  def sequence_field?(field)
    field[:datatype] == "dna" ||
      field[:name] =~ /DNA/
  end

  def fungi?
    obs.dig(:taxon, :iconic_taxon_name) == "Fungi"
  end

  # TODO: 2024-06-13 jdc. This is buggy.
  # I can't find a reliable way to get Projects via the API.
  # It may be returning only "traditional" Projects (project type is "")
  # Is there a better way?
  # See https://github.com/MushroomObserver/mushroom-observer/issues/1955#issuecomment-2164323992
  def inat_projects
    obs[:project_observations]
  end

  def inat_taxon
    obs[:taxon]
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
