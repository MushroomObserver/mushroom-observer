# frozen_string_literal: true

module Account
  # The profile checkbox that keeps the user's iNat observations' images
  # and notes from being imported (#5521). Takes effect only with a
  # linked iNat account, which is how imports recognize the user.
  class InatOptOutsController < ApplicationController
    before_action :login_required

    def update
      opt_out = params.dig(:user, :inat_import_opt_out) == "1"
      @user.update!(inat_import_opt_out: opt_out)
      flash_notice(opt_out ? :inat_opt_out_on.l : :inat_opt_out_off.l)
      redirect_to(edit_account_profile_path)
    end
  end
end
