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
      return text_name.split.first if code_name?(row)
      # The last word in text_name could be Group or Complex
      return text_name_without_last_word(text_name) if group?(row)

      text_name
    end

    # Qualifies unpublished MO text_name.
    # Examples: nom. prov., comb. prov., group, sensu lato, sensu auct.
    def identification_qualifier(row)
      return nil unless unregistrable_name?(row)
      return CODE_NAME_QUALIFIER if code_name?(row)
      return group_token(row) if group?(row)
      return prov_token(row) if provisional?(row)

      row.name_author&.match(/sensu.*/)&.[](0)
    end

    # Full name+author for code names, provisional names, and groups
    def taxon_remarks(row)
      return unless code_name?(row) || provisional?(row) || group?(row)

      "#{row.name_text_name} #{row.name_author}".strip
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

    ####### Additional columns and utilities

    # extended data used to calculate some values
    # See app/classes/report/base_table.rb
    def extend_data!(rows)
      add_collector_ids!(rows, 1)
      add_herbarium_accession_numbers!(rows, 2)
      add_sequence_ids!(rows, 3)
      add_gps_hidden!(rows, 4)
    end

    def collector_ids(row)
      row.val(1)
    end

    def herbarium_accession_numbers(row)
      row.val(2)
    end

    def sequence_ids(row)
      row.val(3)
    end

    def gps_hidden?(row)
      row.val(4).present?
    end

    def sort_before(rows)
      rows.sort_by(&:obs_id)
    end

    ##########

    private

    def group?(row)
      row.name_text_name.match?(/(group|complex|clade)$/)
    end

    def group_token(row)
      row.name_text_name.match(/(group|complex|clade)$/)[0]
    end

    def text_name_without_last_word(text_name)
      text_name.split[0...-1].join(" ")
    end

    def unregistrable_name?(row)
      group?(row) ||
        sensu_non_stricto?(row) ||
        provisional?(row) ||
        code_name?(row)
    end

    def sensu_non_stricto?(row)
      row.name_author.present? &&
        row.name_author.match(/sensu(?!.*stricto)/)
    end

    def provisional?(row)
      row.name_author&.match?(/\w+\. prov\./)
    end

    def prov_token(row)
      row.name_author&.match(/\w+\. prov\./)&.[](0)
    end

    def code_name?(row)
      row.name_text_name.match?(/'/)
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

    def add_gps_hidden!(rows, col)
      latlng_by_id = gps_hidden_latlng
      rows.each { |row| set_gps_hidden_vals(row, col, latlng_by_id) }
    end

    def gps_hidden_latlng
      plain_query.where(gps_hidden: true).
        pluck(:id, :lat, :lng).
        to_h { |id, lat, lng| [id, [lat, lng]] }
    end

    def set_gps_hidden_vals(row, col, latlng_by_id)
      return unless (latlng = latlng_by_id[row.obs_id])

      row.add_val("1", col)
      row.add_val(latlng[0]&.round, col + 1)
      row.add_val(latlng[1]&.round, col + 2)
    end

    def information_withheld(row)
      return unless gps_hidden?(row)

      GPS_HIDDEN_MESSAGE
    end

    def public_lat(row)
      gps_hidden?(row) ? row.val(5) : row.best_lat
    end

    def public_lng(row)
      gps_hidden?(row) ? row.val(6) : row.best_lng
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
