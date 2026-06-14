# frozen_string_literal: true

module Admin
  # Allow users to make monetary donations via the website
  class DonationsController < AdminController
    def new
      @donation = Donation.new
      render(Views::Controllers::Admin::Donations::New.new(donation: @donation))
    end

    def create
      @donation = create_donation(params)
    end

    # Review donations
    def edit
      @donations = Donation.order(created_at: :desc)
      render(Views::Controllers::Admin::Donations::Edit.new(
               donations: @donations.to_a
             ))
    end

    def update
      update_donations(params[:reviewed])
      @donations = Donation.order(created_at: :desc)
      render(Views::Controllers::Admin::Donations::Edit.new(
               donations: @donations.to_a
             ))
    end

    private

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
