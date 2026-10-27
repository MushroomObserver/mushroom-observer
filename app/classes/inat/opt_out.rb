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
  end
end
