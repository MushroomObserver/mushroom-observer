# frozen_string_literal: true

# Sidebar admin nav: excluded iNat users list.
class Tab::Sidebar::Admin::ExcludedInatUsers < Tab::Base
  def title
    :excluded_inat_users_title.l
  end

  def path
    admin_excluded_inat_users_path
  end
end
