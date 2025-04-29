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
        # scientificName joins sciname and scientificNameAuthorship.
        # We need to supply them separately
        "sciname",
        "scientificNameAuthorship",
        "taxonRank",
        # "genus",
        # "specificEpithet",
        "infraspecificEpithet",
        "identificationQualifier",
        "recordedBy",
        "recordNumber", # collection no. assigned to specimen by the collector
        "disposition", # controlled vocab: "vouchered" or nil
        "eventDate",
        "year",
        "month",
        "day",
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
        # NOTE: email from Scott Bates 2025-04-24 12:25 PDT
        # We just need a species name (sciname) AND
        # authors (scientificNameAuthorship) fields,
        # the rest (e.g., family and genus etc.) is automatically generated
        sciname(row), # sciname
        scientific_name_authorship(row), # scientificNameAuthorship
        row.name_rank, # taxonRank
        # row.genus, # genus
        # row.species, # specificEpithet
        row.form_or_variety_or_subspecies, # infraspecificEpithet
        identification_qualifier(row), # identificationRemarks
        collector(row), # recordedBy
        number(row), # collectors number || "MUOB #{observation.id}", Cf. obs_id
        disposition(row), # disposition
        row.obs_when, # eventDate
        row.year, # year
        row.month, # month
        row.day, # day
        row.country, # country
        row.state, # stateProvince
        row.county, # county
        row.locality, # locality
        row.best_lat, # decimalLatitude
        row.best_lng, # decimalLongitude
        lat_lng_uncertainty(row), # coordinateUncertaintyInMeters
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

    def scientific_name_authorship(row)
      if row.name_rank == "Group"
        binomial = text_name_without_last_word(row.name_text_name)
        Name.find_by(text_name: binomial).try(:author)
      else
        row.name_author
      end
    end

    def identification_qualifier(row)
      match = row.name_author&.match(/(sensu.*)/)
      return match[1] if match

      return "group" if row.name_rank == "Group"
      return "nom. prov." if obs(row).name.provisional?

      nil
    end

    def obs(row)
      Observation.find(row.obs_id)
    end

    def collector(row)
      collector_and_number(row).first
    end

    def number(row)
      collector_and_number(row).second
    end

    def collector_and_number(row)
      if row.val(2).blank?
        [row.user_name_or_login, "MUOB #{row.obs_id}"]
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
    def lat_lng_uncertainty(row)
      # If obs has lat/lng and isn't hidden, we don't know the uncertainty
      return nil if row.obs_lat.present? && !obs(row).gps_hidden?

      if row.obs_lat
        "placeholder for uncertainty" # TODO: add uncertainty to the report
      else
        distance_from_center_to_farthest_corner(row)
      end
    end

    def distance_from_center_to_farthest_corner(row)
      loc = obs(row).location
      return nil if loc.blank?

      distance_to_farthest_corner(loc.center_lat, loc.center_lng, loc)
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

    def distance_to_farthest_corner(lat, lng, loc)
      [
        distance_to_ne_corner(lat, lng, loc),
        distance_to_se_corner(lat, lng, loc),
        distance_to_nw_corner(lat, lng, loc),
        distance_to_sw_corner(lat, lng, loc)
      ].max
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
