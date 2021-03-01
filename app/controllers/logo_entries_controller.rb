# frozen_string_literal: true

class LogoEntriesController < ApplicationController
  def new
    @logo_entry = LogoEntry.new
  end

  def create
    upload = params["logo_entry"]["image"]
    copyright_holder = params["logo_entry"]["copyright_holder"]
    image = Image.new(image: upload,
                      user: @user,
                      when: Date.today,
                      copyright_holder: copyright_holder,
                      license: License.first)
    if !image.save
      flash_object_errors(image)
    elsif !image.process_image
      logger.error("Unable to upload image")
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
    redirect_to(new_logo_entry_path)
  end
end
