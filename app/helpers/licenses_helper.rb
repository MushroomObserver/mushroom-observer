# frozen_string_literal: true

# helpers for show License view
module LicensesHelper
  def show_license_title(license)
    [
      license.display_name,
      license_title_id(license)
    ].safe_join(" ")
  end

  # "Editing: Creative Commons Non-commercial v3.0 (#nnn)"  textilized
  def license_edit_title(license)
    capture do
      concat("#{:EDITING.l}: ")
      concat(show_license_title(license))
    end
  end

  def license_title_id(license)
    tag.span(class: "smaller") do
      tag.span("#(#{license.id || "?"}):")
    end
  end

  def license_updated_at(license)
    if license.updated_at
      license.updated_at.strftime("%Y-%m-%d %H:%M:%S")
    else
      "nil"
    end
  end
end
