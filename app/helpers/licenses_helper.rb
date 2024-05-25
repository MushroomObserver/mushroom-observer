# frozen_string_literal: true

# helpers for show License view
module LicensesHelper
  def show_license_title(license)
    [
      license_title_id(license),
      license.display_name
    ].safe_join(" ")
  end
end

def license_title_id(license)
  tag.span(class: "smaller") do
    [:show_license_header.l, tag.span("#{license.id || "?"}:")].safe_join(" ")
  end
end

def license_updated_at(license)
  if license.updated_at
    license.updated_at.strftime("%Y-%m-%d %H:%M:%S")
  else
    "nil"
  end
end
