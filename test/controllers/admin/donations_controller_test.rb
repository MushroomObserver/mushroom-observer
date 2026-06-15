# frozen_string_literal: true

require("test_helper")

module Admin
  class DonationsControllerTest < FunctionalTestCase
    # NOTE: zeitwerk does not autoload the /tests directory
    require_relative("../donations_controller_test_helpers")
    include ::DonationsControllerTestHelpers

    def test_new_donation
      get(:new)
      assert_response(:redirect)
      make_admin("rolf")
      get(:new)
      # Phlex `Admin::Donations::New` renders the create-donation form.
      assert_select("form[action='#{admin_donations_path}']")
    end

    def test_create_donation
      create_donation(false, false)
    end

    def test_create_donation_anon_recurring
      create_donation(true, true)
    end

    def create_donation(anon, recurring)
      make_admin
      amount = 100.00
      donations = Donation.count
      params = donation_params(amount, rolf, anon, recurring)
      post(:create, params: params)
      assert_donations(donations + 1, amount, true, params[:donation])
    end

    def test_review_donations
      get(:edit)
      assert_response(:redirect)
      make_admin
      get(:edit)
      # Phlex `Admin::Donations::Edit` renders the review form (id pinned
      # by the form Phlex class).
      assert_select("form#admin_review_donations_form")
    end

    def test_update_reviewed_donations
      make_admin
      unreviewed = donations(:unreviewed)
      assert_not(unreviewed.reviewed)
      params = { reviewed: { unreviewed.id => true } }
      put(:update, params: params)
      reloaded = Donation.find(unreviewed.id)
      assert(reloaded.reviewed)
    end
  end
end
