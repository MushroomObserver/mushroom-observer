# frozen_string_literal: true

# When a user's verified iNat login is on the admins' exclusion list,
# the setting moves to the user's profile and the row leaves the list,
# so one identity is governed in one place (#5521).
module ClaimsExcludedInatLogin
  extend ActiveSupport::Concern

  included do
    after_save :claim_excluded_inat_login, if: :saved_change_to_inat_username?
  end

  private

  def claim_excluded_inat_login
    entry = ExcludedInatUser.find_by(inat_login: inat_username)
    return unless entry

    update_column(:inat_import_opt_out, true)
    entry.destroy!
  end
end
