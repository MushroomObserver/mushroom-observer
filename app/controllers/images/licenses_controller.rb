# frozen_string_literal: true

# Images::LicensesController
module Images
  class LicensesController < ApplicationController
    before_action :login_required

    # Linked from show_obs, account prefs tabs and section, acct profile
    # Tabular form that lets user change licenses of their images.  The table
    # groups all the images of a given copyright holder and license type into
    # a single row.  This lets you change all Rolf's licenses in one stroke.
    # Linked from: account/preferences/edit

    # was #license_updater.
    def edit
      @form = build_form_object
      render_edit_view
    end

    # process_license_changes
    def update
      Image.process_license_changes_for_user(@user, params[:updates])

      @form = build_form_object
      render_edit_view(location: images_edit_licenses_path)
    end

    private

    def render_edit_view(**)
      render(Views::Controllers::Images::Licenses::Edit.new(
               form: @form, user: @user
             ), **)
    end

    def build_form_object
      FormObject::ImageLicenseUpdates.new(
        data: Image.licenses_for_user_by_type(@user)
      )
    end
  end
end
