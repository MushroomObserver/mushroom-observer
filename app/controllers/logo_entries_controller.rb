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
end
