# frozen_string_literal: true

# "Create donation" admin link. Distinct from `Tab::Support::NewDonation`
# in carrying the `Donation` model (so the auto-derived selector class
# is `_donation_link` rather than a plain title-derived one) — the
# admin donations index uses this; the donor-facing support page uses
# Tab::Support::NewDonation.
class Tab::Admin::CreateDonation < Tab::Base
  def title
    :create_donation_tab.t
  end

  def path
    new_admin_donations_path
  end

  def model
    Donation
  end
end
