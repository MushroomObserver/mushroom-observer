# frozen_string_literal: true

class Admin::BannersController < AdminController
  def new
    @banner = Banner.current || Banner.new
    render_new_view
  end

  def create
    @banner = Banner.new(banner_params)

    if @banner.save
      flash_notice(:banner_update_success.t)
      redirect_to(new_admin_banner_path)
    else
      flash_error(:banner_update_failure.t)
      @banner = Banner.current || @banner
      render_new_view_invalid
    end
  end

  private

  def render_new_view(status: :ok, **render_opts)
    render(Views::Controllers::Admin::Banners::New.new(banner: @banner),
           status: status, **render_opts)
  end

  def banner_params
    params.require(:banner).permit(:message).
      merge(version: Banner.next_version)
  end
end
