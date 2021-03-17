# frozen_string_literal: true

class ContestEntriesController < ApplicationController
  before_action :admin_required

  def new
    @contest_entry = ContestEntry.new
  end

  def create
    copyright_holder = params["contest_entry"]["copyright_holder"]
    image = build_image(params["contest_entry"]["image"],
                        @user,
                        copyright_holder)
    alternate_image = build_image(params["contest_entry"]["alternate_image"],
                                  @user,
                                  copyright_holder)
    if image
      @contest_entry = ContestEntry.create!(image: image,
                                            alternate_image: alternate_image)
    end
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

    flash_error(:admins_only.t)
    redirect_to(controller: "observer", action: "list_rss_logs")
    false
  end

  def build_image(param_image, user, copyright_holder)
    return nil unless param_image

    image = Image.new(image: param_image,
                      user: user,
                      when: Time.zone.today,
                      copyright_holder: copyright_holder,
                      license: License.first)
    if !image.save
      flash_object_errors(image)
    elsif !image.process_image
      unable_to_upload(image)
    else
      name = image.original_name
      name = "##{image.id}" if name.empty?
      flash_notice(:runtime_profile_uploaded_image.t(name: name))
      return image
    end
    nil
  end

  def unable_to_upload(image)
    logger.error("Unable to upload image")
    name = image.original_name
    name = "???" if name.empty?
    flash_error(:runtime_profile_invalid_image.t(name: name))
    flash_object_errors(image)
  end
end
