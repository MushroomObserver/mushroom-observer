# frozen_string_literal: true

# helpers for show License view
module LicensesHelper
  # "Editing: Creative Commons Non-commercial v3.0 (#nnn)" textilized
  def license_edit_title(license)
    capture do
      concat("#{:EDITING.l}: ")
      concat(license_show_title(license))
    end
  end

  def license_show_title(license)
    [
      license.display_name,
      license_title_id(license)
    ].safe_join(" ")
  end

  def license_title_id(license)
    tag.span(class: "smaller") do
      tag.span("#(#{license.id || "?"}):")
    end
  end

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
