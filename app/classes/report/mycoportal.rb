# frozen_string_literal: true

# Report (a TSV spreadsheet) for exporting Observations to MyCoPortal
# https://mycoportal.org/
# https://www.mycoportal.org/portal/api/v2/documentation

# MyCoPortal is built on Symbiota
# https://symbiota.org/
# https://docs.symbiota.org/
# https://github.com/Symbiota/Symbiota
module Report
  class Mycoportal < CSV
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
      NameResolver.new(row).sciname
    end

    # Qualifies unpublished MO text_name.
    # Examples: nom. prov., comb. prov., group, sensu lato, sensu auct.,
    # aff. section, aff. <code name epithet>
    def identification_qualifier(row)
      NameResolver.new(row).identification_qualifier
    end

    # Full name+author for code names, provisional names, groups, and
    # infrageneric ranks (section, subgenus, etc.)
    def taxon_remarks(row)
      NameResolver.new(row).taxon_remarks
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

        CoordinateUncertainty.max_distance_to_any_corner(
          public_lat(row), public_lng(row), loc_box(row)
        )
      elsif row.obs_lat.blank?
        CoordinateUncertainty.distance_from_center_to_farthest_corner(
          loc_box(row)
        )
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
      add_collector_ids!(rows, :collector_ids)
      add_herbarium_accession_numbers!(rows, :herbarium_accession_numbers)
      add_sequence_ids!(rows, :sequence_ids)
      add_gps_hidden!(rows)
      add_correct_spelling!(rows)
    end

    def collector_ids(row)
      row.val(:collector_ids)
    end

    def herbarium_accession_numbers(row)
      row.val(:herbarium_accession_numbers)
    end

    def sequence_ids(row)
      row.val(:sequence_ids)
    end

    def gps_hidden?(row)
      row.val(:gps_hidden_flag).present?
    end

    def sort_before(rows)
      @included_observation_ids = rows.map(&:obs_id)
      rows.sort_by(&:obs_id)
    end

    # Records every Observation included in the most recent #body call as
    # exported to MyCoPortal (creating or refreshing its ExternalLink), so
    # a future run's "updated since last export" check has something to
    # compare against. A separate step from #body -- not automatic -- so
    # merely computing a CSV never has the side effect of marking
    # observations as sent; only an explicit post-generation call does.
    def mark_exported!
      unless @included_observation_ids
        raise("mark_exported! called before body")
      end

      export_observations!
    end

    ##########

    private

    # Misspelled MO Names must never reach MCP under the wrong spelling --
    # substitute the correctly-spelled Name's text_name/author/rank for
    # every downstream calculation. Batched over the distinct Names in
    # this batch of rows, not per-row.
    def add_correct_spelling!(rows)
      corrections = correct_spellings_by_name_id(rows)
      rows.each do |row|
        correction = corrections[row.name_id]
        next unless correction

        row.add_val(correction[:text_name], :corrected_text_name)
        row.add_val(correction[:author], :corrected_author)
        row.add_val(correction[:rank], :corrected_rank)
      end
    end

    def correct_spellings_by_name_id(rows)
      name_ids = rows.map(&:name_id).uniq
      Name.where(id: name_ids).where.not(correct_spelling_id: nil).
        includes(:correct_spelling).index_by(&:id).
        transform_values { |name| correct_spelling_vals(name) }
    end

    def correct_spelling_vals(name)
      correct = name.correct_spelling
      { text_name: correct.text_name, author: correct.author,
        rank: correct.rank }
    end

    # Bookkeeping only -- must never let a failure here (e.g. a missing
    # ExternalSite row, a DB error) turn an already-computed, valid CSV
    # into a 500. See Report::MycoportalImageList#export_images! for the
    # same reasoning.
    def export_observations!
      site = ExternalSite.mycoportal
      now = Time.current
      @included_observation_ids.each do |obs_id|
        upsert_export_link(site, obs_id, now)
      end
    rescue StandardError => e
      Rails.logger.error(
        "MyCoPortal export-tracking failed: #{e.class}: #{e.message}"
      )
    end

    # Creates the Observation's export link on first export, or refreshes
    # last_synced_at on a re-export -- unlike images (never re-sent),
    # observations can be updated and re-exported.
    def upsert_export_link(site, obs_id, synced_at)
      link = ExternalLink.find_by(target_type: "Observation",
                                  target_id: obs_id, external_site: site,
                                  relationship: :export)
      if link
        link.update!(last_synced_at: synced_at)
      else
        ExternalLink.create!(user: User.admin, target_type: "Observation",
                             target_id: obs_id, external_site: site,
                             relationship: :export, last_synced_at: synced_at)
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn(
        "MyCoPortal export link failed for Observation #{obs_id}: " \
        "#{e.message}"
      )
    end

    def loc_box(row)
      Mappable::Box.new(north: row.loc_north, south: row.loc_south,
                        east: row.loc_east, west: row.loc_west)
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
