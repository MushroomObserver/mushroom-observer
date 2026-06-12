# frozen_string_literal: true

# Action-nav for the admin donations new form.
class Tab::Admin::DonationsFormNew < Tab::Collection
  private

  def tabs
    [Tab::Support::Donate.new,
     Tab::Support::Donors.new,
     Tab::Support::ReviewDonations.new]
  end
end
