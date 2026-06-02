# frozen_string_literal: true

# "Bulk update image licenses" link.
class Tab::Account::BulkLicenseUpdater < Tab::Base
  def title
    :bulk_license_link.t
  end

  def path
    images_edit_licenses_path
  end
end
