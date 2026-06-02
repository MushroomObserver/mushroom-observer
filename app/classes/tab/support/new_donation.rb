# frozen_string_literal: true

# "Create donation" admin link.
class Tab::Support::NewDonation < Tab::Base
  def title
    :create_donation_tab.t
  end

  def path
    new_admin_donations_path
  end
end
