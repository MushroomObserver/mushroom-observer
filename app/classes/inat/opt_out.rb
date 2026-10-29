# frozen_string_literal: true

class Inat
  # Whether an iNat observer has opted out of having their data included
  # on MO (#5521): either an MO user who ticked the profile checkbox, or
  # an iNat user on the admins' exclusion list. An opted-out observer's
  # observations are imported the way an unlicensed one's are: the facts,
  # with no images and no notes.
  module OptOut
    # inat_user: the `user` hash of an iNat API observation.
    def self.opted_out?(inat_user)
      login = inat_user.to_h[:login].to_s
      User.exists?(inat_username: login.downcase, inat_import_opt_out: true) ||
        ExcludedInatUser.matching(login: login, id: inat_user.to_h[:id]).
          present?
    end

    # Every opted-out login, for iNat's `not_user_id` filter.
    def self.logins
      (User.where(inat_import_opt_out: true).where.not(inat_username: nil).
        pluck(:inat_username) + ExcludedInatUser.pluck(:inat_login)).uniq
    end

    # iNat API args leaving out opted-out observers; none when there are
    # none, since an empty `not_user_id` would be sent to iNat as is.
    def self.filter_args
      logins = self.logins
      logins.empty? ? {} : { not_user_id: logins.join(",") }
    end
  end
end
