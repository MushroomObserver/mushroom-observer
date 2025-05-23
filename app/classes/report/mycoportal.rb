# frozen_string_literal: true

module Report
  # Report for exporting Observations to MyCoPortal
  # https://mycoportal.org/
  # https://www.mycoportal.org/portal/api/v2/documentation
  #
  # MyCoPortal is built on Symbiota
  # https://symbiota.org/
  # https://biokic.github.io/symbiota-docs/
  # https://github.com/Symbiota/Symbiota
  class Mycoportal < TSV
    # These plus Column labels comprising
    # Symbiota Standard Field names which are useful for our purposes
    # https://biokic.github.io/symbiota-docs/editor/edit/fields/#standard-fields
    # plus MO-specific fields that are useful for uploads to Symbiota portals
    def labels
      [
        # "occid", # MCP's internal id of the record : 7962944,
        # "collid", # id of MCP's MO collection :  36
        # "basisOfRecord", # : "HumanObservation",
        "scientificName",
        "scientificNameAuthorship",
        "taxonRank",
        "genus",
        "specificEpithet",
        "infraspecificEpithet",
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
        "minimumElevationInMeters",
        "maximumElevationInMeters",
        "dateLastModified",
        "substrate",
        "host",
        "fieldNotes",
        "mushroomObserverId", # probably should be dbpk, : "514",
        "observationUrl",
        "imageUrls"
      ]
    end

    def format_row(row) # rubocop:disable Metrics/AbcSize
      [
        row.name_text_name, # scientificName
        row.name_author, # scientificNameAuthorship
        row.name_rank, # taxonRank
        row.genus, # genus
        row.species, # specificEpithet
        row.form_or_variety_or_subspecies, # infraspecificEpithet
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
        row.best_low, # minimumElevationInMeters
        row.best_high, # maximumElevationInMeters
        row.obs_updated_at, # dateLastModified
        substrate(row), # MyCoPortal `substrate` == Sybiota/DWC substrate
        host(row), # MyCoPortal `host` == Sybiota/DWC associatedTaxa
        field_notes(row), # occurrenceRemarks
        row.obs_id, # MCP `dpk`; catalogNumber = "MUOB #{observation.id}"
        row.obs_url, # MO-specific; used in MCP Desciption / verbatimAttributes
        image_urls(row) # MO-specific
      ]
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
      explode_notes(row).first
    end

    def host(row)
      explode_notes(row).second
    end

    def field_notes(row)
      explode_notes(row).third
    end

    def explode_notes(row)
      notes = row.obs_notes_as_hash || {}
      [
        extract_notes_field(notes, :Substrate),
        extract_notes_field(notes, :Host),
        export_other_notes(notes)
      ]
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

    def sort_before(rows)
      rows.sort_by(&:obs_id)
    end

    def extend_data!(rows)
      add_image_ids!(rows, 1)
      add_collector_ids!(rows, 2)
      add_herbarium_accession_numbers!(rows, 3)
    end
  end
end
