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
#  inat_identifications    array of identifications, taxa need not be unique
#  inat_location::         lat,lon
#  inat_obs_fields::       array of fields, each field a hash
#  inat_obs_photos::       array of observation_photos
#  inat_place_guess::
#  inat_private_location:: lat, lon
#  inat_project_names::
#  inat_prov_name::        provisional species name
#  inat_positional_accuracy::  accuracy of inat_location in meters
#  inat_public_positional_accuracy::  blurred accuracy
#  inat_quality_grade::    casual, needs id, research
#  inat_tags::             array of tags
#  inat_taxon_name::       scientific name
#  inat_taxon_rank::       rank (can be secondary)
#  inat_user_login
#
#  == MO attributes
#  gps_hidden
#  license::
#  name_id
#  notes
#  lat
#  lng
#  location
#  text_name
#  when
#  where
#
# == Other mappings used in MO Observations
#
#  dqa::               data quality grade
#  provisional_name::  MO text_name corresponding to inat_prov_name
#
# == Utilities
#
#  importable?::  Is it importable to MO?
#
class InatObs
  def initialize(imported_inat_obs_data)
    @obs = JSON.parse(imported_inat_obs_data, symbolize_names: true)
  end

  ########## iNat attributes

  def inat_id
    @obs[:id]
  end

  def inat_identifications
    @obs[:identifications]
  end

  # iNat fudges this for obscured observations. Cf. inat_private_location
  # https://help.inaturalist.org/en/support/solutions/articles/151000169938-what-is-geoprivacy-what-does-it-mean-for-an-observation-to-be-obscured-
  def inat_location
    @obs[:location]
  end

  # for test purposes
  def inat_location=(location)
    @obs[:location] = location
  end

  def inat_obs_fields
    @obs[:ofvs]
  end

  def inat_obs_photos
    @obs[:observation_photos]
  end

  def inat_place_guess
    @obs[:place_guess]
  end

  def inat_private_location
    @obs[:private_location]
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

  # NOTE: iNat allows only 1 obs field with a given :name per obs.
  # I assume iNat users will add only 1 proviisonal name per obs
  def inat_prov_name
    obs_fields = inat_obs_fields
    return nil if obs_fields.blank?

    prov_name_field =
      inat_obs_fields.find do |field|
        field[:name] =~ /^Provisional Species Name/
      end
    return nil if prov_name_field.blank?

    prov_name_field[:value]
  end

  # unblurred accuracy. Cf. inat_public_positional_accuracy
  # https://help.inaturalist.org/en/support/solutions/articles/151000169938-what-is-geoprivacy-what-does-it-mean-for-an-observation-to-be-obscured-
  def inat_positional_accuracy
    @obs[:public_positional_accuracy]
  end

  # For testing. It's often much easier to modify an existing mock obs
  # than to create a new one.
  def inat_positional_accuracy=(accuracy)
    @obs[:positional_accuracy] = accuracy
  end

  # Blurred for obscured observations. Cf. inat_positional_accuracy
  # https://help.inaturalist.org/en/support/solutions/articles/151000169938-what-is-geoprivacy-what-does-it-mean-for-an-observation-to-be-obscured-
  def inat_public_positional_accuracy
    @obs[:public_positional_accuracy]
  end

  # For testing. It's often much easier to modify an existing mock obs
  # than to create a new one.
  def inat_public_positional_accuracy=(accuracy)
    @obs[:public_positional_accuracy] = accuracy
  end

  def inat_quality_grade
    @obs[:quality_grade]
  end

  def inat_tags
    @obs[:tags]
  end

  def inat_taxon
    @obs[:taxon]
  end

  def inat_taxon_name
    inat_taxon[:name]
  end

  def inat_taxon_rank
    inat_taxon[:rank]
  end

  def inat_user_login
    @obs[:user][:login]
  end

  ########## MO attributes

  def gps_hidden
    @obs[:geoprivacy].present?
  end

  def license
    InatLicense.new(@obs[:license_code]).mo_license
  end

  def name_id
    names = if complex?
              matching_group_names
            else
              matching_names_at_regular_ranks
            end
    best_mo_name(names)
  end

  def notes
    return "" if description.empty?

    { Other: description.gsub(%r{</?p>}, "") }
  end

  # min bounding rectangle of iNat location blurred by public accuracy
  def location
    Location.contains_box(n: blurred_north,
                          s: blurred_south,
                          e: blurred_east,
                          w: blurred_west).
      min_by { |loc| location_box(loc).box_area }
  end

  # location seems simplest source for lat/lng
  # But :geojason might be possible.
  def lat
    location = inat_private_location || inat_location
    location.split(",").first.to_f
  end

  def lng
    location = inat_private_location || inat_location
    location.split(",").second.to_f
  end

  def sequences
    obs_sequence_fields = inat_obs_fields.select { |f| sequence_field?(f) }
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
    observed_on = @obs[:observed_on_details]
    Date.new(observed_on[:year], observed_on[:month], observed_on[:day])
  end

  def where
    # FIXME: Make it a real MO Location
    # Maybe smallest existing MO Location containing:
    #   inat.location +/- inat.positional accuracy
    inat_place_guess
  end

  ########## Other mappings used in MO Observations

  def dqa
    case inat_quality_grade
    when "research"
      :inat_dqa_research.l
    when "needs_id"
      :inat_dqa_needs_id.l
    when "casual"
      :inat_dqa_casual.l
    end
  end

  # The MO text_name for an iNat provisional species name
  def provisional_name
    prov_sp_name = inat_prov_name
    return nil if prov_sp_name.blank?
    return prov_sp_name if in_mo_format?(prov_sp_name)

    # prepend the epithet with "sp-"
    # epithet must start with lower case letter, else MO thinks it's an author
    # quote the epithet by convention to indicate it will be replaced
    # by a ICN style published or provisional name.
    # Ex: Donadinia PNW01 => Donadinia "sp-PNW01"
    prov_sp_name.sub(/ (.*)/, ' "sp-\1"')
  end

  ########## Utilities

  def public_accuracy_in_degrees
    accuracy_in_meters = (inat_public_positional_accuracy || 0).to_f

    { lat: accuracy_in_meters / 111_111,
      lng: accuracy_in_meters / 111_111 * Math.cos(to_rad(lat)) }
  end

  def importable?
    taxon_importable?
  end

  def taxon_importable?
    fungi? || slime_mold?
  end

  ##########

  private

  # ----- location-related

  # These give a good approximation of the iNat blurred bounding box
  def blurred_north
    [lat + public_accuracy_in_degrees[:lat] / 2, 90].min
  end

  def blurred_south
    [lat - public_accuracy_in_degrees[:lat] / 2, -90].max
  end

  def blurred_east
    ((lng + public_accuracy_in_degrees[:lng] / 2 + 180) % 360) - 180
  end

  def blurred_west
    ((lng - public_accuracy_in_degrees[:lng] / 2 + 180) % 360) - 180
  end

  def to_rad(degrees)
    degrees * Math::PI / 180.0
  end

  # copied from AutoComplete::ForLocationContaining
  def location_box(loc)
    Mappable::Box.new(north: loc[:north], south: loc[:south],
                      east: loc[:east], west: loc[:west])
  end

  # ---- name-related

  def full_name
    if infrageneric?
      # iNat :name string is only the epithet. Ex: "Distantes"
      prepend_genus_and_rank
    elsif infraspecific?
      # iNat :name string omits the rank. Ex: "Inonotus obliquus sterilis"
      insert_rank_between_species_and_final_epithet
    elsif complex?
      # iNat doesn't include "complex" in the name, MO does
      "#{inat_taxon[:name]} complex"
    else
      inat_taxon[:name]
    end
  end

  def infrageneric?
    %w[subgenus section subsection stirps series subseries].
      include?(inat_taxon[:rank])
  end

  def prepend_genus_and_rank
    # Search the identifications of this iNat observation
    # for an identification of the inat_taxon[:id]
    inat_identifications.each do |identification|
      next unless identifies_this_obs?(identification)

      # search the identification's ancestors to find the genus
      identification[:taxon][:ancestors].each do |ancestor|
        next unless ancestor[:rank] == "genus"

        #  return a string comprising Genus rank epithet
        #  ex: "Morchella section Distantes"
        return "#{ancestor[:name]} #{inat_taxon[:rank]} #{inat_taxon[:name]}"
      end
    end
  end

  def infraspecific?
    %w[subspecies variety form].include?(inat_taxon[:rank])
  end

  def insert_rank_between_species_and_final_epithet
    words = inat_taxon[:name].split
    "#{words[0..1].join(" ")} #{inat_taxon[:rank]} #{words[2]}"
  end

  def identifies_this_obs?(identification)
    identification[:taxon][:id] == inat_taxon[:id]
  end

  def matching_group_names
    # MO equivalent could be group, clade, or complex
    # Tried AREL:
    # Name.where(Name[:text_name] =~ /^#{inat_taxon_name}/).
    # and got this:
    # (rdbg) names
    # #<ActiveRecord::StatementInvalid: Trilogy::ProtocolError: 3692:
    #   Incorrect description of a {min,max} interval.> rescued
    #   during inspection
    Name.where(text_name: "#{inat_taxon_name} complex").
      or(Name.where(text_name: "#{inat_taxon_name} group")).
      or(Name.where(text_name: "#{inat_taxon_name} clade")).
      where(rank: "Group", correct_spelling_id: nil).
      order(deprecated: :asc)
  end

  def matching_names_at_regular_ranks
    Name.where(
      # parse it to get MO's text_name rank abbreviation
      # E.g. "sect." instead of "section"
      text_name: Name.parse_name(full_name).text_name,
      rank: inat_taxon[:rank].titleize,
      correct_spelling_id: nil
    ).
      # iNat lacks taxa "sensu xxx", so ignore MO Names sensu xxx
      where.not(Name[:author] =~ /^sensu /).
      order(deprecated: :asc)
  end

  def best_mo_name(names)
    # It's simplest to pick the 1st one if there are any
    # (They've already been sorted)
    return names.first.id if names.any?

    Name.unknown.id
  end

  def in_mo_format?(prov_sp_name)
    # Genus followed by quoted epithet starting with a lower-case letter
    prov_sp_name =~ /[A-Z][a-z]+ "[a-z]\S+"/
  end

  # ----- Other

  def complex?
    inat_taxon_rank == "complex"
  end

  def description
    @obs[:description]
  end

  def fungi?
    @obs.dig(:taxon, :iconic_taxon_name) == "Fungi"
  end

  # TODO: 2024-07-23 jdc. Improve this.
  # (But the best possible is Traditional projects and
  # non_traditional_projects with joined Collection/Umbrella projects )
  # https://forum.inaturalist.org/t/given-an-observation-id-get-a-list-of-project/53476?u=joecohen
  def inat_projects
    @obs[:project_observations]
  end

  def sequence_field?(field)
    field[:datatype] == "dna" ||
      field[:name] =~ /DNA/ && field[:value] =~ /^[ACTG]{,10}/
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
    @obs.dig(:taxon, :iconic_taxon_name) == "Protozoa"
  end
end
