# frozen_string_literal: true

# An iNaturalist user with no MO account whose observations MO does not
# import images or notes from (#5521). Admins keep the list. An iNat
# user with an MO account opts out on their profile instead
# (User#inat_import_opt_out); one identity is governed in one place, so
# the row leaves this table when an MO account claims the login.
#
#  inat_login::   iNat login, lowercase.
#  inat_user_id:: iNat's numeric user id, recorded the first time an
#                 import sees the login; matches survive a login change.
#  user::         Admin who added the entry.
#  reason::       Optional note.
class ExcludedInatUser < ApplicationRecord
  include NormalizesInatLogin

  belongs_to :user, optional: true

  validates :inat_login, presence: true, uniqueness: true,
                         format: { with: Inat::Constants::LOGIN_PATTERN }
  validate :not_an_mo_users_login, on: :create

  # The entry an iNat user (login and id from iNat's API) matches, if
  # any. A login match missing the id records it.
  def self.matching(login:, id:)
    entry = find_by(inat_user_id: id) if id.present?
    entry ||= find_by(inat_login: login.to_s.downcase) if login.present?
    entry&.record_inat_user_id(id)
    entry
  end

  # The MO user who has claimed this login, if any.
  def mo_user
    User.find_by(inat_username: inat_login)
  end

  def record_inat_user_id(id)
    update_column(:inat_user_id, id) if inat_user_id.nil? && id.present?
  end

  private

  def not_an_mo_users_login
    return unless mo_user

    errors.add(:inat_login, :excluded_inat_user_has_account)
  end
end
