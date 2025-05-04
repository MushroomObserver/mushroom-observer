# frozen_string_literal: true

require "haversine"

# Report (a TSV spreadsheet) for exporting Observations to MyCoPortal
# https://mycoportal.org/
# https://www.mycoportal.org/portal/api/v2/documentation

# MyCoPortal is built on Symbiota
# https://symbiota.org/
# https://biokic.github.io/symbiota-docs/
# https://github.com/Symbiota/Symbiota
module Report
  class Mycoportal < TSV
    # http_domain for links to Observations and Images
    HTTP_DOMAIN = "https://mushroomobserver.org"

    # Label names for the columns in the report.
    # Some Symbiota Standard Fields
    # https://biokic.github.io/symbiota-docs/editor/edit/fields/#standard-fields
    # plus some MyCoPortal-specific fields
    # Includes only fields needed for upload to MyCoPortal.
    # MyCoPortal fills in other fields automatically.
    def labels
      [
        "dbpk", # MCP-specific; MO observation.id; was "mushroomObserverId",
        "basisOfRecord", # : "HumanObservation",
        "catalogNumber", # "MUOB" + space + observation.id"
        "sciname",
        "scientificNameAuthorship",
        "identificationQualifier",
        "recordedBy",
        "recordNumber", # collection no. assigned to specimen by the collector
        "eventDate",
        "substrate",
        "occurrenceRemarks", # MO observation.notes; was fieldNotes
        "associatedTaxa", # was "host"
        "verbatimAttributes", # anchored link to obs; was observationUrl
        "country",
        "stateProvince",
        "county",
        "locality",
        "decimalLatitude",
        "decimalLongitude",
        "coordinateUncertaintyInMeters",
        "minimumElevationInMeters",
        "maximumElevationInMeters",
        "disposition", # herbaria, "vouchered", or nil
        "dateLastModified",
        "imageUrl" # not a Symbiota or MCP field;
      ]
    end

    def format_row(row) # rubocop:disable Metrics/AbcSize
      [
        row.obs_id, # MCP `dpk`; catalogNumber = "MUOB #{observation.id}"
        "HumanObservation", # basisOfRecord
        "MUOB #{row.obs_id}", # catalogNumber
        sciname(row), # (mono- or binomial without author)
        scientific_name_authorship(row),
        identification_qualifier(row), # group, nom. prov., etc.
        row.user_name_or_login, # recordedBy
        record_number(row), # recordNumber
        row.obs_when, # eventDate
        substrate(row),
        occurence_remarks(row), # notes minus substrate and associatedTaxa
        associated_taxa(row), # was`host`
        verbatim_atttributes(row), # anchored link to MO observation url
        row.country, # country
        row.state, # stateProvince
        row.county, # county
        row.locality, # locality
        row.best_lat, # decimalLatitude
        row.best_lng, # decimalLongitude
        coordinate_uncertainty(row), # coordinateUncertaintyInMeters
        row.best_low, # minimumElevationInMeters
        row.best_high, # maximumElevationInMeters
        disposition(row), # disposition
        row.obs_updated_at, # dateLastModified
        image_url(row.obs_thumb_image_id) # MO-specific (not an MCP field)
      ]
    end

    # taxon name, without authority or qualifcation (such as "group")
    def sciname(row)
      text_name = row.name_text_name
      # The last word in text_name could be Group or Complex
      return text_name_without_last_word(text_name) if row.name_rank == "Group"

      text_name
    end

    # The author of the valid, unqualified sciname
    def scientific_name_authorship(row)
      if qualified_name?(row)
        if obs(row).name.provisional?
          ""
        else
          # For MO Group or sensu x names, MCP wants:
          # sciname: valid, unqualified name
          # scientificNameAuthorship: author of valid, unqualified name
          # plus an identification qualifier. Example:
          # MO text_name: Agaricales sensu lato
          #   sciname: Agaricales
          #   scientificNameAuthorship: Underw.
          #   identificationQualifier: sensu lato
          unqualified_name(row).try(:author)
        end
      else
        row.name_author
      end
    end

    # Qualifies unpublished MO text_name.
    # Examples: nom. prov., crypt. temp., group, sensu lato, sensu auct.
    def identification_qualifier(row)
      return nil unless qualified_name?(row)
      return "group #{row.name_author}".strip if row.name_rank == "Group"
      if obs(row).name.provisional?
        return provisional_identification_qualifier(row)
      end

      row.name_author&.match(/sensu.*/)&.[](0)
    end

    # collector's number
    def record_number(row)
      if collector_ids(row).blank?
        ""
      else
        collector_ids(row).split("\n").
          min_by(&:to_i).
          split("\t").last
      end
    end

    def substrate(row)
      explode_notes(row)[:substrate]
    end

    # MO notes
    def occurence_remarks(row)
      return explode_notes(row)[:other] unless obs(row).sequences.any?

      "Sequenced; #{explode_notes(row)[:other]}"
    end

    # host plus associates
    # https://github.com/BioKIC/symbiota-docs/issues/36#issuecomment-1015733243
    def associated_taxa(row)
      host = explode_notes(row)[:host]
      trees_shrubs = explode_notes(row)[:trees_shrubs]

      associates = if host.present?
                     "host: #{host}"
                   else
                     ""
                   end
      return associates if trees_shrubs.blank?

      "#{trees_shrubs}; #{associates}"
    end

    # text of an anchored link to the MO Observation
    def verbatim_atttributes(row)
      "<a href='#{HTTP_DOMAIN}/#{row.obs_id}' " \
      "target='_blank' style='color: blue;'>" \
      "Original observation ##{row.obs_id} (Mushroom Observer)</a>"
    end

    # coordinateUncertaintyInMeters
    def coordinate_uncertainty(row)
      if obs(row).location.blank?
        # Cannot calculate uncertainty without a defined location
        nil
      elsif obs(row).gps_hidden? &&
            obs(row).lat
        distance_from_obs_lat_lng_to_farthest_corner(row)
      elsif obs(row).lat.blank?
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

    # additional columns
    # See app/classes/report/base_table.rb
    def extend_data!(rows)
      add_collector_ids!(rows, 1)
      add_herbarium_accession_numbers!(rows, 2)
    end

    def collector_ids(row)
      row.val(1)
    end

    def herbarium_accession_numbers(row)
      row.val(2)
    end

    def sort_before(rows)
      rows.sort_by(&:obs_id)
    end

    ##########

    private

    def obs(row)
      Observation.find(row.obs_id)
    end

    def text_name_without_last_word(text_name)
      text_name.split[0...-1].join(" ")
    end

    def qualified_name?(row)
      row.name_rank == "Group" ||
        sensu_non_stricto?(row) ||
        obs(row).name.provisional?
    end

    def sensu_non_stricto?(row)
      row.name_author.present? &&
        row.name_author.match(/sensu(?!.*stricto)/)
    end

    def unqualified_name(row)
      if row.name_rank == "Group"
        # For groups, MO appends Group, Complex, etc. to the text_name
        # Remove the last word from the text_name to get the binomial
        mono_or_binomial = text_name_without_last_word(row.name_text_name)
        # return the author of the non-group name
        Name.find_by(text_name: mono_or_binomial)
      else
        # For name sensu xxx (the other kind of qualified name with an author)
        # Return the first un-deprecated non-sensu matching name
        Name.where(text_name: row.name_text_name).
          where.not(Name[:author] =~ /sensu/).
          order(deprecated: :asc).
          first
      end
    end

    def provisional_identification_qualifier(row)
      return "nom. prov." if row.name_author.blank?

      if row.name_author&.match(/(prov|crypt)\./)
        row.name_author
      else
        "#{row.name_author} nom.prov."
      end
    end

    def distance_from_obs_lat_lng_to_farthest_corner(row)
      obs = obs(row)
      loc = obs.location
      distance_to_farthest_corner(obs(row).lat, obs(row).lng, loc)
    end

    def distance_from_center_to_farthest_corner(row)
      loc = obs(row).location
      return nil if loc.blank?

      distance_to_farthest_corner(loc.center_lat, loc.center_lng, loc)
    end

    def distance_to_farthest_corner(lat, lng, loc)
      [
        distance_to_ne_corner(lat, lng, loc),
        distance_to_se_corner(lat, lng, loc),
        distance_to_nw_corner(lat, lng, loc),
        distance_to_sw_corner(lat, lng, loc)
      ].max.to_s
    end

    def distance_to_ne_corner(lat, lng, loc)
      Haversine.distance(lat, lng, loc.north, loc.east).to_meters.round
    end

    def distance_to_se_corner(lat, lng, loc)
      Haversine.distance(lat, lng, loc.south, loc.east).to_meters.round
    end

    def distance_to_nw_corner(lat, lng, loc)
      Haversine.distance(lat, lng, loc.north, loc.west).to_meters.round
    end

    def distance_to_sw_corner(lat, lng, loc)
      Haversine.distance(lat, lng, loc.south, loc.west).to_meters.round
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

        # gsub("??", ""). # Remove Textile italics markup

        t.html_to_ascii
    end

    def image_url(id)
      # This URL is permanent. It should always be correct,
      # no matter how much we change the underlying image server(s).
      # It is large, rather than full-size, because we no longer
      # let anonymous users access full-size images because of
      # bot/scraper issues
      if id.present?
        "#{HTTP_DOMAIN}/images/1280/#{id}.jpg"
      else
        ""
      end
    end
  end
end
