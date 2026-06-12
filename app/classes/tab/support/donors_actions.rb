# frozen_string_literal: true

# Action-nav for the donors page. Admins get the donation-admin
# tabs appended.
class Tab::Support::DonorsActions < Tab::Collection
  def initialize(admin: false)
    super()
    @admin = admin
  end

  private

  def tabs
    base = [Tab::Support::Donate.new]
    return base unless @admin

    base + [Tab::Support::NewDonation.new,
            Tab::Support::ReviewDonations.new]
  end
end
