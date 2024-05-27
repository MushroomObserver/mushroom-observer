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
end
