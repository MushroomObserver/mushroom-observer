# frozen_string_literal: true

# Controller for community support including donations
# and summary letters.
class SupportController < ApplicationController
  def donate
    store_location
    @donation = Donation.new
    @donation.user = @user
    @donation.amount = 100
    return unless @user

    @donation.who = @user.name
    @donation.email = @user.email
  end

  def create_donation
    return unless check_donate_admin(:create_donation_not_allowed.t)

    @donation = if request.method == "POST"
                  post_donation(params)
                else
                  Donation.new
                end
  end

  def check_donate_admin(error)
    return true if in_admin_mode?

    flash_error(error)
    redirect_to(action: "donate")
  end

  def post_donation(params)
    email = params["donation"]["email"]
    Donation.create(amount: params["donation"]["amount"],
                    who: params["donation"]["who"],
                    recurring: params["donation"]["recurring"],
                    anonymous: params["donation"]["anonymous"],
                    email: email,
                    user: find_user(email),
                    reviewed: true)
  end

  def confirm
    @donation = if request.method == "POST"
                  confirm_donation(params["donation"])
                else
                  Donation.new
                end
  end

  def find_user(email)
    users = User.where(email: email)
    return unless users.length == 1

    users[0]
  end

  def confirm_donation(params)
    amount = params["amount"]
    amount = params["other_amount"] if amount == "other"
    return unless valid_amount?(amount, :confirm_positive_number_error.t)

    Donation.create(amount: amount,
                    who: params["who"],
                    recurring: params["recurring"],
                    anonymous: params["anonymous"],
                    email: params["email"],
                    reviewed: false)
  end

  def valid_amount?(amount, error)
    if amount.to_f <= 0
      flash_error(error)
      redirect_to(action: "donate")
      return false
    end
    true
  end

  def review_donations
    return unless check_donate_admin(:review_donations_not_allowed.t)

    update_donations(params[:reviewed]) if request.method == "POST"
    @donations = Donation.all.order("created_at DESC")
    @reviewed = {}
    @donations.each do |d|
      @reviewed[d.id] = d.reviewed
    end
  end

  def update_donations(params)
    params.each do |x, y|
      d = Donation.find(x)
      d.reviewed = y
      d.save
    end
  end

  def donors
    store_location
    @donor_list = Donation.donor_list
  end

  def wrapup_2011
    store_location
  end

  def wrapup_2012
    store_location
  end

  def letter
    store_location
  end

  def thanks
    store_location
  end

  def governance
    store_location
  end
end
