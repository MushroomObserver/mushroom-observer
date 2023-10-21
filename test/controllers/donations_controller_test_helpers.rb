# frozen_string_literal: true

# helper for shared test methods between Support and Admin::Donations
# NOTE: zeitwerk does not autoload the /tests directory

# Usage:
#  class <YourTest> < <YourTestCase>
#    require_relative("path/to/donations_controller_test_helpers")
#    include ::DonationsControllerTestHelpers
module DonationsControllerTestHelpers
  def assert_donations(count, final_amount, reviewed, params)
    donation = Donation.all.order("created_at DESC")[0]
    assert_equal([count, final_amount, reviewed],
                 [Donation.count, donation.amount, donation.reviewed])
    assert_donation_params(params, donation)
  end

  def assert_donation_params(params, donation)
    assert_equal([params[:who], params[:email],
                  params[:anonymous], params[:recurring]],
                 [donation.who, donation.email,
                  donation.anonymous, donation.recurring])
  end

  def donation_params(amount, user, anon, recurring = false)
    {
      donation: {
        amount: amount,
        who: user.name,
        email: user.email,
        anonymous: anon,
        recurring: recurring,
        reviewed: false
      }
    }
  end
end
