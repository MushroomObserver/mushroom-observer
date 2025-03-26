# frozen_string_literal: true

module Report
  # Format for export to NAMA.
  class Nama < CSV
    NAMA_PROJECT_NAME = "North American Mycological Association"

    NAMA_LABELS = [
      "Record Number",
      "Field Photo",
      "iNat number",
      "MO number",
      "MycoFlora Number",
      "Genus",
      "Det",
      "Species_Epithet",
      "Subspecies_Epithet",
      "Variety_Epithet",
      "Forma_Epithet",
      "Sensu",
      "Synonym",
      "DetBy",
      "Collector",
      "CollDate",
      "Country",
      "StateProv",
      "County",
      "Town",
      "Site Name",
      "Precise Location",
      "LatDeg",
      "LongDeg",
      "Elevation in M",
      "Substrate",
      "Tree Associates",
      "Habit",
      "CollNote",
      "Disposition",
      "DNA Status",
      "CollNumber",
      "Specimen status",
      "Walk Number"
    ].freeze

    def labels
      NAMA_LABELS
    end

    def format_row(row)
      ["N/A", field_photo(row)] +
        id_fields(row) +
        name_fields(row) +
        people_fields(row) +
        [row.obs_when] +
        location_fields(row) +
        notes_fields(row)
    end

    private

    def field_photo(row)
      return "Yes" if /\+ *photo/i.match?(row.notes_export_formatted)

      ""
    end

    def id_fields(row)
      [
        row.inat_id,
        row.obs_id,
        field_slip_code(row)
      ]
    end

    def field_slip_code(row)
      field_slip = FieldSlip.find_by(observation_id: row.obs_id)
      field_slip&.code
    end

    def name_fields(row)
      [
        row.genus,
        det(row),
        row.species,
        row.subspecies,
        row.variety,
        row.form,
        sensu(row.name_author),
        synonym(row)
      ]
    end

    def det(row)
      obs_name = row.notes_to_hash[:Field_Slip_ID]
      return "aff." if obs_name&.include?("aff.")

      ""
    end

    def sensu(author)
      return author if /sensu/.match?(author)

      ""
    end

    def synonym(row)
      fs_name = row.notes_to_hash[:Field_Slip_ID]
      obs_name = row.name_text_name
      return "" if fs_name&.include?(obs_name)

      fs_name&.delete("_")
    end

    def people_fields(row)
      [
        identifier(row),
        collector(row)
      ]
    end

    def identifier(row)
      user_name(row.notes_to_hash[:Field_Slip_ID_By])
    end

    def collector(row)
      user_name(row.notes_to_hash[:Collector])
    end

    def user_name(name_str)
      return name_str unless name_str

      @user_names ||= {}
      return @user_names[name_str] if @user_names.include?(name_str)

      result = find_user_name(name_str)
      @user_names[name_str] = result
    end

    def find_user_name(name_str)
      login = name_str[/\A_user (.*?)_/, 1]
      return name_str unless login

      user = User.find_by(login:)
      return user.unique_text_name if user

      name_str
    end

    def location_fields(row)
      [
        row.country,
        row.state,
        row.county,
        town(row.locality),
        site(row.locality),
        "",
        row.best_lat(4),
        row.best_lng(4),
        row.best_alt
      ]
    end

    def town(locality)
      return locality.split(",", 2).first if locality&.include?(",")

      ""
    end

    def site(locality)
      return locality.split(",", 2).second if locality&.include?(",")

      locality
    end

    def notes_fields(row)
      [
        row.notes_to_hash[:Substrate],
        row.notes_to_hash[:"Trees/Shrubs"],
        row.notes_to_hash[:Habit],
        row.notes_to_hash[:Other],
        "",
        sequence_code(row.notes_to_hash[:Other_Codes]),
        "",
        "",
        ""
      ]
    end

    def sequence_code(codes)
      codes && (codes[/NEF24-\d+/] || "")
    end
  end
end
