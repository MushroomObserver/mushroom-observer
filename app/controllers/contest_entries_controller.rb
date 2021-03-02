# frozen_string_literal: true

class ContestEntriesController < ApplicationController
  before_action :admin_required

  def new
    @contest_entry = ContestEntry.new
  end

  def create
    upload = params["contest_entry"]["image"]
    copyright_holder = params["contest_entry"]["copyright_holder"]
    image = build_image(upload,
                        @user,
                        Time.zone.today,
                        copyright_holder,
                        License.first)
    @contest_entry = ContestEntry.create!(image: image) if image
    redirect_to(new_contest_entry_path)
  end

  def index
    query = create_query(
      :ContestEntry,
      :all,
      by: :created_at
    )
    show_index_of_objects(query, {})
  end

  def show
    if (@contest_entry = find_or_goto_index(ContestEntry, params[:id]))
      @canonical_url = contest_entry_url(@contest_entry.id)
    else
      false
    end
  end

  private

  def admin_required
    return true if in_admin_mode?

    flash_error(:admins_only)
    redirect_to(controller: "observer", action: "list_rss_logs")
    false
  end

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
