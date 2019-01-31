module ObservationReport
  # Special format for Adolf.
  class Adolf < ObservationReport::CSV
    self.mime_type = "application/vnd.ms-excel"

    # rubocop:disable Metrics/MethodLength
    def labels
      [
        "Database Field",
        "Herbarium",
        "Accession Number",
        "Genus",
        "Qualifier",
        "Species",
        "Species Author",
        "Subspecies",
        "Subspecies Author",
        "Variety",
        "Variety Author",
        "Country",
        "ProvinceState",
        "Location",
        "VStart_LatDegree",
        "VStart_LongDegree",
        "VEnd_LatDegree",
        "VEnd_LongDegree",
        "Grid Ref.",
        "Habitat",
        "Host Substratum",
        "Altitude",
        "Date",
        "Collector",
        "Other Collectors",
        "Number",
        "Determined by",
        "Notes",
        "Originally identified as",
        "Annotation 1",
        "Annotation 2",
        "Annotation 3",
        "More Annotations",
        "Original Herbarium",
        "GenBank",
        "Herbarium Notes",
        "WWW comments",
        "Database number",
        "MO Observation ID",
        "Specimen Available"
      ]
    end

    # rubocop:disable Metrics/AbcSize Metrics/MethodLength
    def format_row(row)
      notes, orig_label = parse_orig_label(row)
      [
        nil,
        nil,
        nil,
        row.genus,
        row.cf,
        row.species,
        row.species_author,
        row.subspecies,
        row.subspecies_author,
        row.variety,
        row.variety_author,
        row.country,
        row.state,
        row.locality_with_county,
        row.best_south,
        row.best_west,
        row.best_north,
        row.best_east,
        nil,
        nil,
        nil,
        row.obs_alt,
        row.obs_when,
        row.user_name_or_login,
        nil,
        nil,
        nil,
        notes,
        orig_label,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        row.obs_id,
        row.obs_specimen
      ]
    end

    def parse_orig_label(row)
      notes = row.obs_notes
      if notes&.sub!(/original herbarium label: *(\S[^\n\r]*\S)/i, "")
        orig_label = Regexp.last_match(1).gsub(/_(.*?)_/, '\\1')
        [notes.strip, orig_label]
      else
        [notes, nil]
      end
    end

    def sort_before(rows)
      rows.sort_by(&:name_text_name)
    end
  end
end
