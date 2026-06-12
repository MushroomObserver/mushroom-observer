# frozen_string_literal: true

# Action-nav for the admin donations edit form.
class Tab::Admin::DonationsFormEdit < Tab::Collection
  private

  def tabs
    [Tab::Support::Donate.new,
     Tab::Support::Donors.new,
     Tab::Admin::CreateDonation.new]
  end
end
