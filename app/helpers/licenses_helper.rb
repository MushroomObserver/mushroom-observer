# frozen_string_literal: true

# helpers for show License view
module LicensesHelper
  def license_updated_at(license)
    if license.updated_at
      license.updated_at.strftime("%Y-%m-%d %H:%M:%S")
    else
      "nil"
    end
  end

  def license_table_header
    [
      "Default?",
      "#{:ID.l}:",
      :license_display_name.l,
      :license_url.l,
      "#{:deprecated.l}?"
    ]
  end

  def license_table_rows
    License.all.each_with_object([]) do |license, rows|
      rows << [
        license.preferred? ? "X" : "",
        license.id.to_s,
        link_to_object(license, license.display_name),
        link_to(license.url, license.url),
        license.deprecated ? "X" : ""
      ]
    end
  end
end
