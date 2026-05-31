# frozen_string_literal: true

require "haversine"

# Report (a TSV spreadsheet) for exporting Observations to MyCoPortal
# https://mycoportal.org/
# https://www.mycoportal.org/portal/api/v2/documentation

# MyCoPortal is built on Symbiota
# https://symbiota.org/
# https://docs.symbiota.org/
# https://github.com/Symbiota/Symbiota
module Report
  class Mycoportal < CSV
    CODE_NAME_QUALIFIER = "code name aff. species"
    GPS_HIDDEN_MESSAGE = "Coordinates obscured by observer"
    EXCLUDED_TEXT_NAMES = (
      %w[Duplicate Undetermined Eukarya Eukaryota] +
      ["Mixed collection", "Non-fungal", "Slime-flux"]
    ).freeze
    INFRAGENERIC_RANKS = %w[Stirps Series Subsection Section Subgenus].freeze

    # MCP uses Symbiota, which is largely based on Darwin Core (DwC).
    # Label names for the columns in the report.
    # https://docs.symbiota.org/Collection_Manager_Guide/Importing_Uploading/data_import_fields/
    # See also https://docs.symbiota.org/Editor_Guide/Editing_Searching_Records/symbiota_data_fields/
    # Includes only fields needed for upload to MyCoPortal.
    # MyCoPortal fills in other fields automatically.
    def labels
      [
        # dbpk (database primary key); required for snapshot collections;
        # Not a DwC standard field
        "dbpk", # observation.id
        "basisOfRecord", # : "HumanObservation"
        "catalogNumber", # "MUOB" + space + observation.id
        "occurrenceID", # GUID. The Observation URL. It must never change.
        "sciname", # scientific name without author; not a DwC standard field
        "identificationQualifier",
        "taxonRemarks",
        "recordedBy",
        "recordNumber", # collection no. assigned to specimen by the collector
        "eventDate",
        "substrate",
        "occurrenceRemarks", # MO observation.notes; was fieldNotes
        "associatedTaxa", # was "host"
        "country",
        "stateProvince",
        "county",
        "locality",
        "decimalLatitude",
        "decimalLongitude",
        "coordinateUncertaintyInMeters",
        "informationWithheld",
        "minimumElevationInMeters",
        "maximumElevationInMeters",
        "disposition" # herbaria, "vouchered", or nil
      ]
    end

    def format_row(row) # rubocop:disable Metrics/AbcSize
      [
        row.obs_id, # (dbpk database primary key)
        "HumanObservation", # basisOfRecord
        "MUOB #{row.obs_id}", # catalogNumber
        "https://mushroomobserver.org/obs/#{row.obs_id}", # occurrenceID
        sciname(row), # (mono- or binomial without author)
        identification_qualifier(row), # group, nom. prov., etc.
        taxon_remarks(row),
        row.user_name_or_login, # recordedBy
        record_number(row), # recordNumber
        row.obs_when, # eventDate
        substrate(row),
        occurence_remarks(row), # notes minus substrate and associatedTaxa
        associated_taxa(row), # was`host`
        row.country, # country
        row.state, # stateProvince
        row.county, # county
        row.locality, # locality
        public_lat(row), # decimalLatitude
        public_lng(row), # decimalLongitude
        coordinate_uncertainty(row), # coordinateUncertaintyInMeters
        information_withheld(row), # informationWithheld
        row.best_low, # minimumElevationInMeters
        row.best_high, # maximumElevationInMeters
        disposition(row) # disposition
      ]
    end

    # taxon name, without authority or qualification (such as "group")
    def sciname(row)
      text_name = row.name_text_name
      return genus_from_gen_name(text_name) if gen_name?(row)
      return text_name.split.first if infrageneric?(row) ||
                                      unpublished_name?(row) ||
                                      code_name?(row)
      # The last word in text_name could be Group or Complex
      return text_name_without_last_word(text_name) if group?(row)

      text_name
    end

    # Qualifies unpublished MO text_name.
    # Examples: aff. species, aff. section, group, sensu lato, sensu auct.
    def identification_qualifier(row)
      return "aff. #{row.name_rank.downcase}" if reduce_to_genus?(row)
      return nil unless unregistrable_name?(row)
      return CODE_NAME_QUALIFIER if code_name?(row)
      return group_token(row) if group?(row)

      row.name_author&.match(/sensu.*/)&.[](0)
    end

    # search_name for genus-reduced, code, and group names
    def taxon_remarks(row)
      return unless reduce_to_genus?(row) || code_name?(row) ||
                    group?(row) || sensu_non_stricto?(row)

      row.name_search_name
    end

    # collector's number
    def record_number(row)
      return if collector_ids(row).blank?

      collector_ids(row).split("\n").
        min_by(&:to_i).split("\t").last
    end

    def substrate(row)
      explode_notes(row)[:substrate]
    end

    # MO notes
    def occurence_remarks(row)
      return explode_notes(row)[:other] unless sequence_ids(row)

      "Sequenced; #{explode_notes(row)[:other]}"
    end

    # host plus associates
    # https://docs.symbiota.org/Editor_Guide/Editing_Searching_Records/symbiota_data_fields/#associated-taxa
    def associated_taxa(row)
      host = explode_notes(row)[:host]
      trees_shrubs = explode_notes(row)[:trees_shrubs]

      associates = "host: #{host}" if host.present?
      return associates if trees_shrubs.blank?

      "#{trees_shrubs}; #{associates}"
    end

    # coordinateUncertaintyInMeters
    def coordinate_uncertainty(row)
      return if row.loc_id.blank?

      if gps_hidden?(row)
        return unless public_lat(row) && public_lng(row)

        box = loc_box(row)
        max_distance_to_any_corner(public_lat(row), public_lng(row), box)
      elsif row.obs_lat.blank?
        distance_from_center_to_farthest_corner(row)
      end
    end

    # "vouchered" or 1st herbarium where deposited
    def disposition(row)
      return nil unless row.obs_specimen

      str = herbarium_accession_numbers(row).to_s.split("\n").map do |val|
        # just herbaria; ignore accession number because our data is garbage
        val.split("\t").first
      end.join("; ")
      return str if str.present?

      "vouchered"
    end

    # extended data used to calculate some values
    # See app/classes/report/base_table.rb
    def extend_data!(rows)
      add_name_kingdoms!(rows)
      add_collector_ids!(rows, :collector_ids)
      add_herbarium_accession_numbers!(rows, :herbarium_accession_numbers)
      add_sequence_ids!(rows, :sequence_ids)
      add_gps_hidden!(rows)
    end

    def include_row?(row)
      return false if EXCLUDED_TEXT_NAMES.include?(row.name_text_name)

      kingdom = row.val(:name_kingdom)
      kingdom.nil? || kingdom.match?(/\A(Fungi|Protozoa)\z/)
    end

    def collector_ids(row) = row.val(:collector_ids)
    def herbarium_accession_numbers(row) = row.val(:herbarium_accession_numbers)
    def sequence_ids(row) = row.val(:sequence_ids)
    def gps_hidden?(row) = row.val(:gps_hidden_flag).present?
    def sort_before(rows) = rows.sort_by(&:obs_id)

    private

    def group?(row) = row.name_text_name.match?(/(group|complex|clade)$/)
    def group_token(row) = row.name_text_name.match(/(group|complex|clade)$/)[0]

    def text_name_without_last_word(text_name)
      text_name.split[0...-1].join(" ")
    end

    def unregistrable_name?(row)
      group?(row) ||
        sensu_non_stricto?(row) ||
        unpublished_name?(row) ||
        code_name?(row)
    end

    def sensu_non_stricto?(row)
      row.name_author.present? &&
        row.name_author.match(/sensu(?!.*stricto)/)
    end

    def gen_name?(row) = row.name_text_name.start_with?("Gen. ")
    def infrageneric?(row) = INFRAGENERIC_RANKS.include?(row.name_rank)
    def genus_from_gen_name(text_name) = text_name.match(/'([^']+)'/)[1]
    def code_name?(row) = row.name_text_name.match?(/'/)

    def unpublished_name?(row)
      row.name_author.to_s.match?(/\w+\.\s*prov\.|nom\.\s*ined/i)
    end

    def reduce_to_genus?(row)
      gen_name?(row) || infrageneric?(row) || unpublished_name?(row)
    end

    def add_name_kingdoms!(rows)
      name_data = Name.where(id: rows.map(&:name_id).uniq).
                  pluck(:id, :rank, :text_name, :classification)
      kingdoms = name_data.to_h { |id, *rest| [id, kingdom_from(*rest)] }
      rows.each { |row| row.add_val(kingdoms[row.name_id], :name_kingdom) }
    end

    def kingdom_from(rank_int, text_name, classif)
      return text_name if Name.ranks.key(rank_int).to_s == "Kingdom"

      classif.to_s.match(/Kingdom: _?([A-Za-z]+)_?/)&.[](1)
    end

    def distance_from_center_to_farthest_corner(row)
      center = loc_box(row).center
      distance_to_farthest_corner(center.first, center.last, loc_box(row))
    end

    def loc_box(row)
      Mappable::Box.new(north: row.loc_north, south: row.loc_south,
                        east: row.loc_east, west: row.loc_west)
    end

    def distance_to_farthest_corner(lat, lng, box)
      # east and west corners are equidistant from center because
      # boxes are isoceles trapezoids with bases parallel to the equator
      # farthest corner belongs to longest base
      if lat.positive?
        distance_to_se_corner(lat, lng, box)
      else
        distance_to_ne_corner(lat, lng, box)
      end
    end

    def distance_to_ne_corner(lat, lng, box)
      Haversine.distance(lat, lng, box.north, box.east).to_meters.round
    end

    def distance_to_se_corner(lat, lng, box)
      Haversine.distance(lat, lng, box.south, box.east).to_meters.round
    end

    def max_distance_to_any_corner(lat, lng, box)
      box_corners(box).map do |clat, clng|
        Haversine.distance(lat, lng, clat, clng).to_meters
      end.max.round
    end

    def box_corners(box)
      [[box.north, box.east], [box.north, box.west],
       [box.south, box.east], [box.south, box.west]]
    end

    def add_gps_hidden!(rows)
      latlng_by_id = gps_hidden_latlng
      rows.each { |row| set_gps_hidden_vals(row, latlng_by_id) }
    end

    def gps_hidden_latlng
      plain_query.where(gps_hidden: true).
        pluck(:id, :lat, :lng).
        to_h { |id, lat, lng| [id, [lat, lng]] }
    end

    def set_gps_hidden_vals(row, latlng_by_id)
      return unless (latlng = latlng_by_id[row.obs_id])

      row.add_val("1", :gps_hidden_flag)
      row.add_val(latlng[0]&.round, :gps_hidden_lat)
      row.add_val(latlng[1]&.round, :gps_hidden_lng)
    end

    def information_withheld(row)
      return unless gps_hidden?(row)

      GPS_HIDDEN_MESSAGE
    end

    def public_lat(row)
      gps_hidden?(row) ? row.val(:gps_hidden_lat) : row.best_lat
    end

    def public_lng(row)
      gps_hidden?(row) ? row.val(:gps_hidden_lng) : row.best_lng
    end

    def explode_notes(row)
      notes = row.obs_notes_as_hash || {}
      {
        substrate: extract_notes_field(notes, :Substrate),
        host: extract_notes_field(notes, :Host),
        trees_shrubs: extract_notes_field(notes, FieldSlip::TREES_SHRUBS),
        other: export_other_notes(notes)
      }
    end

    def extract_notes_field(notes, field)
      clean_notes(notes.delete(field).to_s)
    end

    def export_other_notes(notes)
      clean_notes(Observation.export_formatted(notes))
    end

    def clean_notes(str)
      str.strip.
        # Compress consecutive whitespaces before (not after) Textilizing
        # because some whitespace combinations can confuse Textile
        # Example: `\r\n \r\n`
        gsub(/\s+/, " ").
        t.html_to_ascii
    end
  end
end
