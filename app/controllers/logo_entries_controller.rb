# frozen_string_literal: true

class LogoEntriesController < ApplicationController
  def new
    @logo_entry = LogoEntry.new
  end

  def create
    upload = params["logo_entry"]["image"]
    copyright_holder = params["logo_entry"]["copyright_holder"]
    image = build_image(upload,
                        @user,
                        Time.zone.today,
                        copyright_holder,
                        License.first)
    @logo_entry = LogoEntry.create!(image: image) if image
    redirect_to(new_logo_entry_path)
  end

  def index
    query = create_query(
      :LogoEntry,
      :all,
      by: :created_at
    )
    show_index_of_objects(query, {})
  end

  def show
    if (@logo_entry = find_or_goto_index(LogoEntry, params[:id]))
      @canonical_url = logo_entry_url(@logo_entry.id)
    else
      false
    end
  end

  private

  def build_image(param_image, user, date, copyright_holder, license)
    image = Image.new(image: param_image,
                      user: user,
                      when: date,
                      copyright_holder: copyright_holder,
                      license: license)
    if !image.save
      flash_object_errors(image)
    elsif !image.process_image
      logger.error("Unable to upload image")
      name = image.original_name
      name = "???" if name.empty?
      flash_error(:runtime_profile_invalid_image.t(name: name))
      flash_object_errors(image)
    else
      name = image.original_name
      name = "##{image.id}" if name.empty?
      flash_notice(:runtime_profile_uploaded_image.t(name: name))
      return image
    end
    nil
  end
end
