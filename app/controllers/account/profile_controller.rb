# frozen_string_literal: true

module Account
  class ProfileController < ApplicationController
    before_action :login_required

    def edit
      @licenses = License.current_names_and_ids(@user.license)
      @place_name        = @user.location ? @user.location.display_name : ""
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
      @licenses = License.current_names_and_ids(@user.license)

      [:name, :notes, :mailing_address].each do |arg|
        val = params[:user][arg].to_s
        @user.send("#{arg}=", val) if @user.send(arg) != val
      end

      check_and_maybe_update_user_place_name
      upload_the_image_if_present
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

    def upload_the_image_if_present
      # Check if we need to upload an image.
      upload = params[:user][:upload_image]
      return if upload.blank?

      date = Date.parse("#{params[:date][:copyright_year]}0101")
      license = License.safe_find(params[:upload][:license_id])
      holder = params[:copyright_holder]
      image = Image.new(
        image: upload,
        user: @user,
        when: date,
        copyright_holder: holder,
        license: license
      )
      deal_with_upload_errors_or_success(image)
    end

    def deal_with_upload_errors_or_success(image)
      if !image.save
        flash_object_errors(image)
      elsif !image.process_image
        name = image.original_name
        name = "???" if name.empty?
        flash_error(:runtime_profile_invalid_image.t(name: name))
        flash_object_errors(image)
      else
        @user.image = image
        name = image.original_name
        name = "##{image.id}" if name.empty?
        flash_notice(:runtime_profile_uploaded_image.t(name: name))
      end
    end

    def deal_with_possible_profile_changes
      # compute legal name change now because @user.save will overwrite it
      legal_name_change = @user.legal_name_change
      if !@user.changed
        flash_notice(:runtime_no_changes.t)
        redirect_to(user_path(@user.id))
      elsif !@user.save
        flash_object_errors(@user)
        render(:edit) and return
      else
        update_copyright_holder(legal_name_change)
        maybe_update_location_and_finish
      end
    end

    def update_copyright_holder(legal_name_change = nil)
      return unless legal_name_change

      Image.update_copyright_holder(*legal_name_change, @user)
    end

    def maybe_update_location_and_finish
      if @need_location
        flash_notice(:runtime_profile_must_define.t)
        redirect_to(location_create_location_path,
                    where: @place_name, set_user: @user.id)
      else
        flash_notice(:runtime_profile_success.t)
        redirect_to(user_path(@user.id))
      end
    end
  end
end
