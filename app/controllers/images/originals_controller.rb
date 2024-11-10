# frozen_string_literal: true

# Images::OriginalsController
module Images
  class OriginalsController < ApplicationController
    before_action :login_required

    def show
      @image = Image.find(params[:id])

      respond_to do |format|
        format.html { redirect_to(@image.cached_original_url) }
        format.json { cache_original_image }
      end
    end

    def cache_original_image
      if on_image_server?
        render(json: { status: "ready", url: @image.original_url })
      elsif already_cached?
        render(json: { status: "ready", url: @image.cached_original_url })
      elsif maxed_out?
        render(json: { status: "maxed_out" })
      else
        ImageLoaderJob.perform_later(@image.id)
        render(json: { status: "loading" })
      end
    end

    def on_image_server?
      @image.id >= MO.next_image_id_to_go_to_cloud
    end

    def already_cached?
      File.exist?(@image.cached_original_file_path)
    end

    def maxed_out?
      User.current.increment!(:original_image_quota)
      User.current.original_image_quota > MO.original_image_quota
    end
  end
end
