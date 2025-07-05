# frozen_string_literal: true

#
#  = Inat::Obs Object
#
#  Represents the result of an iNat API search for one observation,
#  mapping iNat key/values to MO Observation attributes
#
#  == Instance methods and attribute keys
#
#  === iNat attributes & associations
#
#  obs::                 The iNat observation data
#  [:id]                 iNat observation id
#  [:identifications]    array of identifications, taxa need not be unique
#  [:location]           lat, lng Nat fudges this for obscured observations
#                        Cf. [:private_location]
#                        https://help.inaturalist.org/en/support/solutions/articles/151000169938-what-is-geoprivacy-what-does-it-mean-for-an-observation-to-be-obscured-
#  inat_obs_fields::       array of fields, each field a hash. == [:ofvs]
#  inat_prov_name_field::  (first) Provisional Species Name field
#  [:observation_photos]   array of photos
#  [:place_guess]          iNat's best guess at the location
#  [:private_location]     lat, lng. Cf. [:location]
#  inat_prov_name::        provisional species name
#  [:positional_accuracy]  unblurred accuracy of [:location] in meters.
#  [:public_positional_accuracy] blurred for obscured observations
#  [:quality_grade]        casual, needs id, research
#  [:tags]                 array of tags
#  [:taxon]                taxon hash
#  inat_taxon_name::       scientific name
#  inat_taxon_rank::       rank (can be secondary)
#  [:user][:login]         username
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
#  dqa::                  data quality grade
#  provisional_name::     MO text_name corresponding to inat_prov_name
#  snapshot::             summary of state of Inat observation
#  suggested_id_names::   suggested id taxon names
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

    # Allow hash key access to the iNat observation data
    delegate :[], to: :@obs

    delegate :[]=, to: :@obs

    ########## iNat attributes

    # convenience method with descriptive, non-cryptic name
    def inat_obs_fields = @obs[:ofvs]

    # The field hash for a given field name
    def inat_obs_field(name)
      inat_obs_fields.find { |field| field[:name] == name }
    end

    # NOTE: Fixes ABC count of `snapshot` because
    # inat_taxon_name is one fewer Branch than self[:taxon][:name]
    def inat_taxon_name = self[:taxon][:name]

    def inat_taxon_rank = self[:taxon][:rank]

    ########## MO attributes

    # disable cop because gps_hidden is a pseudo-attribute
    def gps_hidden = @obs[:geoprivacy].present? # rubocop:disable Naming/PredicateMethod

    def license = Inat::License.new(@obs[:license_code]).mo_license

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
      return { Collector: collector } if self[:description].empty?

      { Collector: collector, Other: self[:description].gsub(%r{</?p>}, "") }
    end

    # min bounding rectangle of iNat location blurred by public accuracy
    def location
      ::Location.contains_box(north: blurred_north,
                              south: blurred_south,
                              east: blurred_east,
                              west: blurred_west).
        min_by { |loc| location_box(loc).calculate_area }
    end

    # location seems simplest source for lat/lng
    # But :geojason might be possible.
    def lat
      location = self[:private_location] || self[:location]
      location.split(",").first.to_f
    end

    def lng
      location = self[:private_location] || self[:location]
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

    def specimen?
      # used by iNat NEMF projects and some others
      field = inat_obs_field("Voucher Specimen Taken")
      field.present? && field[:value] == "Yes"
    end

    def source = "mo_inat_import"

    def text_name = ::Name.find(name_id).text_name

    def when
      observed_on = @obs[:observed_on_details]
      ::Date.new(observed_on[:year], observed_on[:month], observed_on[:day])
    end

    def where = self[:place_guess]

    ########## Other mappings used in MO Observations

    # This will get put into MO Observation's Notes Collector:
    def collector
      if inat_obs_field("Collector").present?
        inat_obs_field("Collector")[:value]
      else
        self[:user][:login]
      end
    end

    def dqa
      case self[:quality_grade]
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
      return nil if inat_prov_name.blank?

      inat_prov_name
    end

    # derive a provisional name from some specific Observation Fields
    # NOTE: iNat does not allow provisional names as identifications.
    # Also, iNat allows only 1 obs field with a given :name per obs,
    # so there can be only 1 Provisional Species Name per obs.
    # NOTE: Edge case -- obs also has Provisional Genus Name, etc.
    # NOTE: I assume iNat users will add only 1 provisional name per obs.
    def inat_prov_name
      prov_name_field = inat_prov_name_field
      return nil if prov_name_field.blank?

      prov_name_field[:value]
    end

    def inat_prov_name_field
      obs_fields = inat_obs_fields
      return nil if obs_fields.blank?

      inat_obs_fields.
        find { |field| field[:name] =~ /^Provisional Species Name/ }
    end

    def snapshot
      snapshop_raw_str.gsub(/^\s+/, "")
    end

    def snapshop_raw_str
      result = ""
      {
        USER: self[:user][:login],
        OBSERVED: self.when,
        show_observation_inat_lat_lng: lat_lon_accuracy,
        PLACE: self[:place_guess],
        ID: inat_taxon_name,
        DQA: dqa,
        show_observation_inat_suggested_ids: suggested_id_names,
        OBSERVATION_FIELDS: obs_fields(inat_obs_fields),
        PROJECTS: :inat_not_imported.t,
        ANNOTATIONS: :inat_not_imported.t,
        TAGS: :inat_not_imported.t
      }.each do |label, value|
        result += "#{label.to_sym.t}: #{value}\n"
      end
      result
    end

    def suggested_id_names
      # Get unique suggested taxon ids
      # (iNat allows multiple suggestions for a single observation)
      "\n#{
        self[:identifications].each_with_object([]) do |id, ary|
          ary << "&nbsp;&nbsp;_#{id[:taxon][:name]}_ by #{id[:user][:login]} " \
          "#{id[:created_at_details][:date]}"
        end.join("\n")
      }"
    end

    def lat_lon_accuracy
      "#{self[:location]} +/-#{self[:public_positional_accuracy]} m"
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
      accuracy_in_meters = (self[:public_positional_accuracy] || 0).to_f

      { lat: accuracy_in_meters / 111_111,
        lng: accuracy_in_meters / 111_111 * Math.cos(to_rad(lat)) }
    end

    def importable? = taxon_importable?

    def taxon_importable? = fungi? || slime_mold?

    ##########

    private

    # ----- location-related

    # These give a good approximation of the iNat blurred bounding box
    def blurred_north = [lat + public_accuracy_in_degrees[:lat] / 2, 90].min

    def blurred_south = [lat - public_accuracy_in_degrees[:lat] / 2, -90].max

    def blurred_east
      ((lng + public_accuracy_in_degrees[:lng] / 2 + 180) % 360) - 180
    end

    def blurred_west
      ((lng - public_accuracy_in_degrees[:lng] / 2 + 180) % 360) - 180
    end

    def to_rad(degrees) = degrees * Math::PI / 180.0

    # copied from Autocomplete::ForLocationContaining
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
        "#{inat_taxon_name} complex"
      else
        inat_taxon_name
      end
    end

    def infrageneric?
      %w[subgenus section subsection stirps series subseries].
        include?(inat_taxon_rank)
    end

    def prepend_genus_and_rank
      # Search the identifications of this iNat observation
      # for an identification of the inat_taxon[:id]
      self[:identifications].each do |identification|
        next unless identifies_this_obs?(identification)

        # search the identification's ancestors to find the genus
        identification[:taxon][:ancestors].each do |ancestor|
          next unless ancestor[:rank] == "genus"

          #  return a string comprising Genus rank epithet
          #  ex: "Morchella section Distantes"
          return "#{ancestor[:name]} #{inat_taxon_rank} #{inat_taxon_name}"
        end
      end
    end

    def infraspecific? = %w[subspecies variety form].include?(inat_taxon_rank)

    def insert_rank_between_species_and_final_epithet
      words = inat_taxon_name.split
      "#{words[0..1].join(" ")} #{inat_taxon_rank} #{words[2]}"
    end

    def identifies_this_obs?(identification)
      identification[:taxon][:id] == self[:taxon][:id]
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
        rank: inat_taxon_rank.titleize,
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

    def complex? = (inat_taxon_rank == "complex")

    def fungi? = (@obs.dig(:taxon, :iconic_taxon_name) == "Fungi")

    def sequence_field?(field)
      field[:datatype] == "dna" ||
        field[:name] =~ /DNA/ && field[:value] =~ /^[ACTG]{,10}/
    end

    # NOTE: 2024-06-01 jdc
    # slime molds are polypheletic https://en.wikipedia.org/wiki/Slime_mold
    # Protoza is paraphyletic for slime molds,
    # but it's how they are classified in MO and MB
    # Can this be improved by checking multiple inat [:taxon][:ancestor_ids]?
    # I.e., is there A combination (ANDs) of higher ranks (>= Class)
    # that's monophyletic for slime molds?
    # Another solution: use IF API to see if IF includes the name.
    def slime_mold? = (@obs.dig(:taxon, :iconic_taxon_name) == "Protozoa")
  end
end
