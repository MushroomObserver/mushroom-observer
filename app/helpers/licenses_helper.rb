# frozen_string_literal: true

# helpers for show License view
module LicensesHelper
  def license_date(date)
    date.strftime("%Y-%m-%d %H:%M:%S")
  end

  def license_table_header
    [
      "#{:ID.l}:",
      :license_display_name.l,
      :license_url.l,
      "#{:deprecated.l}?"
    ]
  end

  def license_table_rows
    License.all.each_with_object([]) do |license, rows|
      rows << [
        license.id.to_s,
        link_to_object(license, license.display_name),
        link_to(license.url, license.url),
        license.deprecated ? "X" : ""
      ]
    end
  end
end
