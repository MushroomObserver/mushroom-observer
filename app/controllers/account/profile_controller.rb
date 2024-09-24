# frozen_string_literal: true

module Account
  class ProfileController < ApplicationController
    before_action :login_required

    def edit
      @licenses = License.available_names_and_ids(@user.license)
      @place_name = @user.location ? @user.location.display_name : ""
      if @user.image
        @copyright_holder  = @user.image.copyright_holder
        @copyright_year    = @user.image.when.year
        @upload_license_id = @user.image.license.id
      else
        @copyright_holder  = @user.legal_name
        @copyright_year    = Time.zone.now.year
        @upload_license_id = @user.license ? @user.license.id : nil
      end
    end

    def update
      @licenses = License.available_names_and_ids(@user.license)

      [:name, :notes, :mailing_address].each do |arg|
        val = params[:user][arg].to_s
        @user.send(:"#{arg}=", val) if @user.send(arg) != val
      end

      check_and_maybe_update_user_place_name
      upload_image_if_present
      deal_with_possible_profile_changes
    end

    private

    def check_and_maybe_update_user_place_name
      # Make sure the given location exists before accepting it.
      @place_name = params[:user][:place_name].to_s
      if @place_name.present?
        location = Location.find_by_name_or_reverse_name(@place_name)
        if !location
          @need_location = true
        elsif @user.location != location
          @user.location = location
          @place_name = location.display_name
        end
      elsif @user.location
        @user.location = nil
      end
    end

    def upload_image_if_present
      # Check if we need to upload an image.
      upload = params[:user][:upload_image]
      return if upload.blank?

      image = upload_image(upload, params[:upload][:copyright_holder],
                           params[:upload][:license_id],
                           params[:upload][:copyright_year])
      return unless image

      @user.image = image
    end

    def deal_with_possible_profile_changes
      if !@user.changed
        flash_notice(:runtime_no_changes.t)
        redirect_to(user_path(@user.id))
      elsif !@user.save
        flash_object_errors(@user)
        render(:edit) and return
      else
        maybe_update_location_and_finish
      end
    end

    def maybe_update_location_and_finish
      if @need_location
        flash_notice(:runtime_profile_must_define.t)
        redirect_to(new_location_path(where: @place_name, set_user: @user.id))
      else
        flash_notice(:runtime_profile_success.t)
        redirect_to(user_path(@user.id))
      end
    end
  end
end
