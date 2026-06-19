# frozen_string_literal: true

# Controller for community support including donations and summary letters
class SupportController < ApplicationController
  before_action :store_location, except: :confirm

  def donate
    @donation = Donation.new
    @donation.user = @user
    @donation.amount = 100
    if @user
      @donation.who = @user.name
      @donation.email = @user.email
    end
    render(Views::Controllers::Support::Donate.new(donation: @donation))
  end

  def confirm
    @donation = if request.method == "POST"
                  confirm_donation(params["donation"])
                else
                  Donation.new
                end
    return if performed?

    render(Views::Controllers::Support::Confirm.new(donation: @donation))
  end

  def donors
    @donor_list = Donation.donor_list
    render(Views::Controllers::Support::Donors.new(
             donor_names: @donor_list.pluck("who")
           ))
  end

  def wrapup_2011
    render(Views::Controllers::Support::Wrapup2011.new)
  end

  def wrapup_2012
    render(Views::Controllers::Support::Wrapup2012.new)
  end

  def letter
    render(Views::Controllers::Support::Letter.new)
  end

  def thanks
    render(Views::Controllers::Support::Thanks.new)
  end

  def governance
    render(Views::Controllers::Support::Governance.new)
  end

  private

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
end
