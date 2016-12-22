# encoding: utf-8

# Controller for community support including donations
# and summary letters.
class SupportController < ApplicationController
  def donate
    store_location
    @donation = Donation.new
    @donation.user = @user
    @donation.amount = 100.00
    return unless @user
    @donation.who = @user.name
    @donation.email = @user.email
  end

  def create_donation
    return unless check_donate_admin(:create_donation_not_allowed.l)
    @donation = if request.method == "POST"
                  post_donation(params)
                else
                  Donation.new
                end
  end

  def check_donate_admin(error)
    return true if is_in_admin_mode?
    flash_error(error)
    redirect_to(action: "donate")
  end

  def post_donation(params)
    email = params["donation"]["email"]
    Donation.create(amount: params["donation"]["amount"],
                    who: params["donation"]["who"],
                    anonymous: params["donation"]["anonymous"],
                    email: email,
                    user: find_user(email),
                    reviewed: true)
  end

  def confirm
    @donation = if request.method == "POST"
                  confirm_donation(params)
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
    amount = params["donation"]["amount"]
    amount = params["donation"]["other_amount"] if amount == "other"
    Donation.create(amount: amount,
                    who: params["donation"]["who"],
                    anonymous: params["donation"]["anonymous"],
                    email: params["donation"]["email"],
                    reviewed: false)
  end

  def review_donations
    return unless check_donate_admin(:review_donations_not_allowed.l)
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
    @donor_list = Donation.get_donor_list
  end

  def wrapup_2010
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
end
