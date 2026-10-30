# frozen_string_literal: true

module Account
  # Deleting the content the user holds, from the profile's Danger Zone.
  class ContentPurgesController < ApplicationController
    include ContentPurgeActions

    before_action :login_required

    private

    def purge_target = { target_user: @user }

    def purge_holder = @user.login

    def purge_path = account_content_purge_path

    def return_path = edit_account_profile_path
  end
end
