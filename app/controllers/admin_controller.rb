# frozen_string_literal: true

#  ==== Admin utilities
#  test_flash_redirection::      <tt>(R . .)</tt>

class AdminController < ApplicationController
  before_action :login_required

  # NOTE: this action does not require admin access.
  def test_flash_redirection
    tags = params[:tags].to_s.split(",")
    if tags.any?
      flash_notice(tags.pop.to_sym.t)
      redirect_to(
        controller: :admin,
        action: :test_flash_redirection,
        tags: tags.join(",")
      )
    else
      # (sleight of hand to prevent localization_file_text from complaining
      # about missing test_flash_redirection_title tag)
      # Disable cop in order to use sleight of hand
      @title = "test_flash_redirection_title".to_sym.t # rubocop:disable Lint/SymbolConversion
      render(layout: "application", html: "")
    end
  end
end
