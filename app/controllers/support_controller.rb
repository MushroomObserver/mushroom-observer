# encoding: utf-8
class SupportController < ApplicationController
  def donate
    store_location
    @donation = Donation.new
    @donation.user = @user
    @donation.amount = 100.00
    if @user
      @donation.who = @user.name
      @donation.email = @user.email
    end
  end

  def create_donation
    if is_in_admin_mode?
      @donation = Donation.new
      if request.method == "POST"
        @donation.amount = params['donation']['amount']
        @donation.who = params['donation']['who']
        @donation.anonymous = params['donation']['anonymous']
        @donation.email = params['donation']['email']
        users = User.where(email: @donation.email)
        if users.length == 1
          @donation.user = users[0]
        end
        @donation.reviewed = true
        @donation.save
      end
    else
      flash_error(:create_donation_not_allowed.l)
      redirect_to(:action => 'donate')
    end
  end

  def confirm
    @donation = Donation.new
    if request.method == "POST"
      amount = params['donation']['amount']
      if amount == "other"
        amount = params['donation']['other_amount']
      end
      @donation.user = @user
      @donation.amount = amount
      @donation.who = params['donation']['who']
      @donation.anonymous = params['donation']['anonymous']
      @donation.email = params['donation']['email']
      @donation.reviewed = false
      @donation.save
    end
  end

  def review_donations
    if is_in_admin_mode?
      if request.method == "POST"
        params[:reviewed].each { |x,y|
          d = Donation.find(x)
          d.reviewed = y
          d.save
        }
      end
      # @donations = Donation.find(:all, :order => "created_at DESC") # Rails 3
      @donations = Donation.all.order("created_at DESC")
      @reviewed = {}
      for d in @donations
        @reviewed[d.id] = d.reviewed
      end
    else
      flash_error(:review_donations_not_allowed.l)
      redirect_to(action: "donate")
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
end
