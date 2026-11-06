# frozen_string_literal: true

module Admin::ExcludedInatUsers
  # Deleting an excluded iNat user's content that is already on MO.
  class ContentPurgesController < AdminController
    include ContentPurgeActions

    before_action :find_excluded_inat_user

    private

    def find_excluded_inat_user
      @excluded = ExcludedInatUser.find(params[:excluded_inat_user_id])
    end

    def purge_target = { inat_login: @excluded.inat_login }

    def purge_holder = :content_purge_inat_holder.l(login: @excluded.inat_login)

    def purge_path = admin_excluded_inat_user_content_purge_path(@excluded)

    def return_path = admin_excluded_inat_users_path
  end
end
