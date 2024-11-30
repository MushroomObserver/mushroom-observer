# frozen_string_literal: true

class Admin::BannersController < AdminController
  def index
    @banner = Banner.current || Banner.new
  end

  def create
    @banner = Banner.new(banner_params)

    if @banner.save
      flash[:success] = :banner_update_success.t
      redirect_to(admin_banners_path)
    else
      flash[:error] = :banner_update_failure.t
      render(:index)
    end
  end

  private

  def banner_params
    params.require(:banner).permit(:message).merge(version: next_version)
  end

  def next_version
    (Banner.maximum(:version) || 0) + 1
  end
end
