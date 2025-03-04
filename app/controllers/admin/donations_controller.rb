# frozen_string_literal: true

module Admin
  # Allow users to make monetary donations via the website
  class DonationsController < AdminController
    def new
      @donation = Donation.new
    end

    def create
      @donation = create_donation(params)
    end

    # Review donations
    def edit
      @donations = Donation.order(created_at: :desc)
      @reviewed = {}
      @donations.each do |d|
        @reviewed[d.id] = d.reviewed
      end
    end

    def update
      update_donations(params[:reviewed])
      @donations = Donation.order(created_at: :desc)
      @reviewed = {}
      @donations.each do |d|
        @reviewed[d.id] = d.reviewed
      end
      render(action: :edit)
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
