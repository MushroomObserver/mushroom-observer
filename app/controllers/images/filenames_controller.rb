# frozen_string_literal: true

# Images::FilenamesController
module Images
  class FilenamesController < ApplicationController
    before_action :login_required
    # NO VIEW TEMPLATE
    # Linked from account/preferences/_privacy

    # bulk_filename_purge
    def update
      Image.where(user_id: User.current_id).update_all(original_name: "")
      flash_notice(:prefs_bulk_filename_purge_success.t)
      redirect_to(edit_account_preferences_path)
    end
  end
end
