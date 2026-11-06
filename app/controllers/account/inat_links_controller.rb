# frozen_string_literal: true

module Account
  # Starts linking the user's iNat account: iNat asks them to authorize
  # MO, then calls back to InatImportsController#authorization_response
  # (see InatImportsController::AccountLinking).
  class InatLinksController < ApplicationController
    include Inat::Constants

    before_action :login_required

    def new
      state = "#{InatImportsController::AccountLinking::LINK_STATE_PREFIX}" \
              "#{SecureRandom.hex(16)}"
      session[:inat_link_state] = state
      redirect_to("#{INAT_AUTHORIZATION_URL}&state=#{state}",
                  allow_other_host: true)
    end
  end
end
