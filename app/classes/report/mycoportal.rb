# frozen_string_literal: true

# Report (a TSV spreadsheet) for exporting Observations to MyCoPortal
# https://mycoportal.org/
# https://www.mycoportal.org/portal/api/v2/documentation

# MyCoPortal is built on Symbiota
# https://symbiota.org/
# https://biokic.github.io/symbiota-docs/
# https://github.com/Symbiota/Symbiota
module Report
  class Mycoportal < TSV
    # Label names for the columns in the report.
    # Some Symbiota Standard Fields
    # https://biokic.github.io/symbiota-docs/editor/edit/fields/#standard-fields
    # plus some MyCoPortal-specific fields
    # Includes only fields needed for upload to MyCoPortal.
    # MyCoPortal fills in other fields automatically.
    def labels
      [
        "basisOfRecord", # : "HumanObservation",
        "catalogNumber", # "MUOB" + space + observation.id"
        "sciname",
        "scientificNameAuthorship",
        "taxonRank",
        "identificationQualifier",
        "recordedBy",
        "recordNumber", # collection no. assigned to specimen by the collector
        "disposition", # controlled vocab: "vouchered" or nil
        "eventDate",
        "country",
        "stateProvince",
        "county",
        "locality",
        "decimalLatitude",
        "decimalLongitude",
        "coordinateUncertaintyInMeters",
        "minimumElevationInMeters",
        "maximumElevationInMeters",
        "dateLastModified",
        "substrate",
        "associatedTaxa", # was "host"
        "occurrenceRemarks", # MO observation.notes; was fieldNotes
        "dbpk", # MCP-specific; MO observation.id; was "mushroomObserverId",
        "verbatimAttributes", # was observationUrl
        "imageUrls" # not a Symbiota or MCP field;
      ]
    end

    def format_row(row) # rubocop:disable Metrics/AbcSize
      [
        "HumanObservation", # basisOfRecord
        "MUOB #{row.obs_id}", # catalogNumber
        sciname(row), # sciname (mono- or binomial without author)
        scientific_name_authorship(row), # scientificNameAuthorship
        row.name_rank, # taxonRank
        identification_qualifier(row), # identificationRemarks
        collector(row), # recordedBy
        number(row), # collectors number || "MUOB #{observation.id}", Cf. obs_id
        disposition(row), # disposition
        row.obs_when, # eventDate
        row.country, # country
        row.state, # stateProvince
        row.county, # county
        row.locality, # locality
        row.best_lat, # decimalLatitude
        row.best_lng, # decimalLongitude
        coordinate_uncertainty(row), # coordinateUncertaintyInMeters
        row.best_low, # minimumElevationInMeters
        row.best_high, # maximumElevationInMeters
        row.obs_updated_at, # dateLastModified
        substrate(row),
        associated_taxa(row), # was`host`
        occurence_remarks(row), # notes minus substrate and associatedTaxa
        row.obs_id, # MCP `dpk`; catalogNumber = "MUOB #{observation.id}"
        observation_link(row), # verbatimAttributes link to MO observation url
        image_urls(row) # MO-specific
      ]
    end

    def sciname(row)
      text_name = row.name_text_name
      # The last word in text_name could be Group or Complex
      return text_name_without_last_word(text_name) if row.name_rank == "Group"

      text_name
    end

    def text_name_without_last_word(text_name)
      text_name.split[0...-1].join(" ")
    end

    # For MO Group or sensu x names, MCP wants:
    # sciname: valid, unqualified name
    # scientificNameAuthorship: author of valid, unqualified name
    # plus an identification qualifier. Example:
    # MO text_name: Agaricales sensu lato
    # MCP sciname: Agaricales
    # MCP scientificNameAuthorship: Underw.
    # MCP identificationQualifier: sensu lato
    def scientific_name_authorship(row)
      if row.name_rank == "Group"
        # For groups, MO appends Group, Complex, etc. to the text_name
        # Remove the last word from the text_name to get the binomial
        mono_or_binomial = text_name_without_last_word(row.name_text_name)
        # return the author of the non-group name
        Name.find_by(text_name: mono_or_binomial).try(:author)
      elsif /sensu.*/.match?(row.name_author)
        name_without_sensu =
          Name.where(text_name: row.name_text_name).
          where.not(Name[:author] =~ /sensu/).first
        name_without_sensu.try(:author)
      else
        row.name_author
      end
    end

    def identification_qualifier(row)
      return nil unless qualified_name?(row)

      return "group" if row.name_rank == "Group"
      return "nom. prov." if obs(row).name.provisional?

      row.name_author&.match(/sensu.*/)&.[](0)
    end

    def collector(row)
      collector_and_number(row).first
    end

    def number(row)
      collector_and_number(row).second
    end

    def collector_and_number(row)
      if row.val(2).blank?
        [row.user_name_or_login, ""]
      else
        row.val(2).split("\n").min_by(&:to_i).split("\t")[1..2]
      end
    end

    def substrate(row)
      explode_notes(row)[:substrate]
    end

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

    def occurence_remarks(row)
      explode_notes(row)[:other]
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

    # coordinateUncertaintyInMeters
    def coordinate_uncertainty(row)
      if obs(row).gps_hidden?
        distance_from_obs_lat_lng_to_farthest_corner(row)
      elsif obs(row).lat.present?
        nil
      else
        distance_from_center_to_farthest_corner(row)
      end
    end

    def image_urls(row)
      row.val(1).to_s.split(", ").sort_by(&:to_i).
        map { |id| image_url(id) }.join(" ")
    end

    def image_url(id)
      # Image.url(:full_size, id, transferred: true)
      # The following URL is the permanent one, should always be correct,
      # no matter how much we change the underlying image server(s) around.
      "#{MO.http_domain}/images/orig/#{id}.jpg"
    end

    def disposition(row)
      return nil unless row.obs_specimen

      str = row.val(3).to_s.split("\n").map do |val|
        # ignore accession number because our data is garbage
        val.split("\t").first
      end.join("; ")
      return str if str.present?

      "vouchered"
    end

    def observation_link(row)
      "<a href='#{row.obs_url}' " \
      "target='_blank' style='color: blue;'>" \
      "Original observation ##{row.obs_id} (Mushroom Observer)</a>"
    end

    def sort_before(rows)
      rows.sort_by(&:obs_id)
    end

    def extend_data!(rows)
      add_image_ids!(rows, 1)
      add_collector_ids!(rows, 2)
      add_herbarium_accession_numbers!(rows, 3)
    end

    ##########

    private

    def obs(row)
      Observation.find(row.obs_id)
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
  end
end
