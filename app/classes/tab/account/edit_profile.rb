# frozen_string_literal: true

# "Edit account profile" link.
class Tab::Account::EditProfile < Tab::Base
  def title
    :profile_link.t
  end

  def path
    edit_account_profile_path
  end
end
