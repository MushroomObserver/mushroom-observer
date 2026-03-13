# frozen_string_literal: true

# Images::OriginalsController
module Images
  class OriginalsController < ApplicationController
    # This is an AJAX request so we can keep overhead low.
    disable_filters

    def show
      # Because this is only called from stimulus within valid pages, we
      # can assume the image is correct... unless a malicious actor is calling
      # this directly, in which case we don't really care if errors are handled
      # gracefully.
      @image = Image.safe_find(params[:id]) or raise("image not found")
      @user = User.current = session_user
      log_request(@user, @image)

      respond_to do |format|
        format.html do
          redirect_to(@image.cached_original_url, allow_other_host: false)
        end
        format.json { cache_original_image }
      end
    end

    def log_request(user, image)
      OriginalImageRequest.create!(
        user_id: user&.id,
        image_id: image.id
      )
    end

    # I'm sorry, but breaking this up would make the method less readable.
    # rubocop:disable Metrics/AbcSize
    def cache_original_image
      if on_image_server?
        render(json: { status: "ready", url: @image.original_url })
      elsif already_cached?
        render(json: { status: "ready", url: @image.cached_original_url })
      elsif !@user
        render(json: { status: "ready", url: @image.url(:huge) })
      elsif already_loading?
        render(json: { status: "loading" })
      elsif user_maxed_out? || site_maxed_out?
        render(json: { status: "maxed_out" })
      else
        # Save job for tester.
        @job = ImageLoaderJob.perform_later(@image.id, @user.id)
        render(json: { status: "loading" })
      end
    end
    # rubocop:enable Metrics/AbcSize

    def on_image_server?
      @image.id >= MO.next_image_id_to_go_to_cloud
    end

    def already_cached?
      File.exist?(@image.cached_original_file_path)
    end

    def already_loading?
      File.exist?("#{@image.cached_original_file_path}.status")
    end

    def user_maxed_out?
      @user.original_image_quota >= MO.original_image_user_quota
    end

    def site_maxed_out?
      User.admin.original_image_quota >= MO.original_image_site_quota
    end
  end
end
