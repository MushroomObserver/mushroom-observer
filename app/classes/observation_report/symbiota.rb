module ObservationReport
  # Symbiota-style tsv report.
  class Symbiota < ObservationReport::TSV
    def labels
      %w[
        scientificName
        scientificNameAuthorship
        taxonRank
        genus
        specificEpithet
        infraspecificEpithet
        recordedBy
        recordNumber
        disposition
        eventDate
        year
        month
        day
        country
        stateProvince
        county
        locality
        decimalLatitude
        decimalLongitude
        minimumElevationInMeters
        maximumElevationInMeters
        dateLastModified
        substrate
        host
        fieldNotes
        mushroomObserverId
        observationUrl
        imageUrls
      ]
    end

    # rubocop:disable Metrics/AbcSize
    def format_row(row)
      [
        row.name_text_name,
        row.name_author,
        row.name_rank,
        row.genus,
        row.species,
        row.form_or_variety_or_subspecies,
        *collector_and_number(row),
        disposition(row),
        row.obs_when,
        row.year,
        row.month,
        row.day,
        row.country,
        row.state,
        row.county,
        row.locality,
        row.best_lat,
        row.best_long,
        row.best_low,
        row.best_high,
        row.obs_updated_at,
        *explode_notes(row),
        row.obs_id,
        row.obs_url,
        image_urls(row)
      ]
    end

    def collector_and_number(row)
      if row.val(2).blank?
        [row.user_name_or_login, "MUOB #{row.obs_id}"]
      else
        row.val(2).split("\n").min_by(&:to_i).split("\t")[1..2]
      end
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
      str.strip.t.html_to_ascii.gsub(/\s+/, " ")
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
