# frozen_string_literal: true

class Admin::BannersController < AdminController
  def index
    @banner = Banner.current || Banner.new
    render_index_view
  end

  def create
    @banner = Banner.new(banner_params)

    if @banner.save
      flash_notice(:banner_update_success.t)
      redirect_to(admin_banners_path)
    else
      flash_error(:banner_update_failure.t)
      @banner = Banner.current || @banner
      render_index_view_invalid
    end
  end

  private

  def render_index_view(status: :ok, **render_opts)
    render(Views::Controllers::Admin::Banners::Index.new(banner: @banner),
           status: status, **render_opts)
  end

  def render_index_view_invalid(**)
    render_index_view(**)
    self.status = :unprocessable_content
  end

  def banner_params
    params.require(:banner).permit(:message).merge(version: next_version)
  end

  def next_version
    (Banner.maximum(:version) || 0) + 1
  end
end
