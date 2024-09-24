# frozen_string_literal: true

#
#  = Inat::Obs Object
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
#  inat_description::
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
class Inat
  class Obs
    def initialize(imported_inat_obs_data)
      @obs = JSON.parse(imported_inat_obs_data, symbolize_names: true)
    end

    ########## iNat attributes & associations

    ATTRIBUTES = [
      :description,
      :id,
      :identifications,
      # https://help.inaturalist.org/en/support/solutions/articles/151000169938-what-is-geoprivacy-what-does-it-mean-for-an-observation-to-be-obscured-
      :location, # Cf. private_location
      # https://help.inaturalist.org/en/support/solutions/articles/151000169938-what-is-geoprivacy-what-does-it-mean-for-an-observation-to-be-obscured-
      :positional_accuracy, # Cf. public_positional_accuracy
      :place_guess,
      :private_location, # Cf. location
      :public_positional_accuracy, # Cf. positional_accuracy
      :quality_grade,
      :tags,
      :taxon
    ].freeze

    ATTRIBUTES.each do |attribute|
      define_method(:"inat_#{attribute}") do
        @obs[attribute]
      end

      define_method(:"inat_#{attribute}=") do |value|
        @obs[attribute] = value
      end
    end

    # iNat Observation Fields
    # https://help.inaturalist.org/en/support/solutions/articles/151000169941-what-are-tags-observation-fields-and-annotations-
    # https://www.inaturalist.org/pages/extra_fields_nz#:~:text=Observation%20fields%20are%20a%20way,who%20do%20it%20all%20themselves.)
    # a less cryptic method name than inat_ofvs
    def inat_obs_fields
      @obs[:ofvs]
    end

    # a shorter method name than inat_observation_photos
    def inat_obs_photos
      @obs[:observation_photos]
    end

    # derive a provisional name from some specific Observation Fields
    # NOTE: iNat does not allow provisional names as Identifications
    # Also, iNat allows only 1 obs field with a given :name per obs.
    # I assume iNat users will add only 1 provisional name per obs
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
      Inat::License.new(@obs[:license_code]).mo_license
    end

    def name_id
      names =
        # iNat "Complex" definition
        # https://www.inaturalist.org/pages/curator+guide#complexes
        if complex?
          matching_group_names
        else
          matching_names_at_regular_ranks
        end
      best_mo_name(names)
    end

    def notes
      return "" if inat_description.empty?

      { Other: inat_description.gsub(%r{</?p>}, "") }
    end

    # min bounding rectangle of iNat location blurred by public accuracy
    def location
      ::Location.contains_box(n: blurred_north,
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
        # NOTE: 2024-06-19 jdc. Need more investigation/test to handle
        # field[:value] blank or not a (pure) lists of bases
        # https://github.com/MushroomObserver/mushroom-observer/issues/2232
        ary << { locus: field[:name], bases: field[:value],
                 # NTOE: 2024-06-19 jdc. Can we figure out the following?
                 archive: nil, accession: "", notes: "" }
      end
    end

    def source
      "mo_inat_import"
    end

    def text_name
      ::Name.find(name_id).text_name
    end

    def when
      observed_on = @obs[:observed_on_details]
      ::Date.new(observed_on[:year], observed_on[:month], observed_on[:day])
    end

    def where
      # NOTE: Make it the name of a real MO Location
      # https://github.com/MushroomObserver/mushroom-observer/issues/2383
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

    def snapshot
      result = ""
      {
        USER: inat_user_login,
        OBSERVED: self.when,
        show_observation_inat_lat_lng: lat_lon_accuracy,
        PLACE: inat_place_guess,
        ID: inat_taxon_name,
        DQA: dqa,
        OBSERVATION_FIELDS: obs_fields(inat_obs_fields),
        PROJECTS: :inat_not_imported.t,
        ANNOTATIONS: :inat_not_imported.t,
        TAGS: :inat_not_imported.t
      }.each do |label, value|
        result += "#{label.to_sym.t}: #{value}\n"
      end
      result.gsub(/^\s+/, "")
    end

    def lat_lon_accuracy
      "#{inat_location} " \
      "+/-#{inat_public_positional_accuracy} m"
    end

    def obs_fields(fields)
      return :none.t if fields.empty?

      "\n#{one_line_per_field(fields)}"
    end

    def one_line_per_field(fields)
      fields.map { |f| "&nbsp;&nbsp;#{f[:name]}: #{f[:value]}" }.
        join("\n")
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
      # MO equivalent could be "group", "clade", or "complex"
      ::Name.where(::Name[:text_name] =~ /^#{inat_taxon_name}/).
        where(rank: "Group", correct_spelling_id: nil).
        order(deprecated: :asc)
    end

    def matching_names_at_regular_ranks
      ::Name.where(
        # parse it to get MO's text_name rank abbreviation
        # E.g. "sect." instead of "section"
        text_name: ::Name.parse_name(full_name).text_name,
        rank: inat_taxon[:rank].titleize,
        correct_spelling_id: nil
      ).
        # iNat lacks taxa "sensu xxx", so ignore MO Names sensu xxx
        where.not(::Name[:author] =~ /^sensu /).
        order(deprecated: :asc)
    end

    def best_mo_name(names)
      # It's simplest to pick the 1st one if there are any
      # (They've already been sorted)
      return names.first.id if names.any?

      ::Name.unknown.id
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

    # NOTE: 2024-09-09 jdc. Can this be improved?
    # https://github.com/MushroomObserver/mushroom-observer/issues/2245
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
end
