# frozen_string_literal: true

module Admin
  class DonationsController < ApplicationController
    before_action :login_required

    def authorize?(_user)
      in_admin_mode?
    end

    def access_denied
      # error for #new and #create was :create_donation_not_allowed.t
      # error for #edit and #update was :review_donations_not_allowed.t

      flash_error(:permission_denied.t)
      if session[:user_id]
        redirect_to(support_donate_path)
      else
        redirect_to(new_account_login_path)
      end
    end

    def new
      @donation = Donation.new
    end

    def create
      @donation = create_donation(params)
    end

    # Review donations
    def edit
      @donations = Donation.all.order(created_at: :desc)
      @reviewed = {}
      @donations.each do |d|
        @reviewed[d.id] = d.reviewed
      end
    end

    def update
      update_donations(params[:reviewed])
      @donations = Donation.all.order(created_at: :desc)
      @reviewed = {}
      @donations.each do |d|
        @reviewed[d.id] = d.reviewed
      end
    end

    private

    def check_donate_admin(error)
      return true if in_admin_mode?

      flash_error(error)
      redirect_to(support_donate_path)
    end

    def create_donation(params)
      email = params["donation"]["email"]
      Donation.create(amount: params["donation"]["amount"],
                      who: params["donation"]["who"],
                      recurring: params["donation"]["recurring"],
                      anonymous: params["donation"]["anonymous"],
                      email: email,
                      user: find_user(email),
                      reviewed: true)
    end

    def find_user(email)
      users = User.where(email: email)
      return unless users.length == 1

      users[0]
    end

    def update_donations(params)
      params.each do |x, y|
        d = Donation.find(x)
        d.reviewed = y
        d.save
      end
    end
  end
end
