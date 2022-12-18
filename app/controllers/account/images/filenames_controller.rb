# frozen_string_literal: true

# Account::Images::FilenamesController
module Account::Images
  class FilenamesController < ApplicationController
    before_action :login_required
    # Linked from account/preferences/_privacy
    # Move to new controller Account::Images::FilenamesController#update
    # Move test from images_controller_test

    # bulk_filename_purge
    def update
      Image.where(user_id: User.current_id).update_all(original_name: "")
      flash_notice(:prefs_bulk_filename_purge_success.t)
      redirect_to(edit_account_preferences_path)
    end
  end
end
