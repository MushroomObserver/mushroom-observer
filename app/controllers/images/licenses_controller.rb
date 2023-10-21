# frozen_string_literal: true

# Images::LicensesController
module Images
  class LicensesController < ApplicationController
    before_action :login_required

    # Linked from show_obs, account prefs tabs and section, acct profile
    # Tabular form that lets user change licenses of their images.  The table
    # groups all the images of a given copyright holder and license type into
    # a single row.  This lets you change all Rolf's licenses in one stroke.
    # Linked from: account/prefs

    # was #license_updater.
    def edit
      # Gather data for form.
      @data = Image.licenses_for_user_by_type(@user) # license_data
    end

    # process_license_changes
    def update
      Image.process_license_changes_for_user(@user, params[:updates])

      @data = Image.licenses_for_user_by_type(@user) # license_data
      render(:edit, location: images_edit_licenses_path)
    end
  end
end
