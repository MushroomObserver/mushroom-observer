# frozen_string_literal: true

module TestPages
  class FlashRedirectionController < ApplicationController
    before_action :login_required

    # NOTE: this action does not require admin access.
    def show
      tags = params[:tags].to_s.split(",")
      if tags.any?
        flash_notice(tags.pop.to_sym.t)
        redirect_to(test_pages_flash_redirection_path(tags: tags.join(",")))
      else
        # (sleight of hand to prevent localization_file_text from complaining
        # about missing test_flash_redirection_title tag)
        # Disable cop in order to use sleight of hand
        @title = "test_flash_redirection_title".to_sym.t # rubocop:disable Lint/SymbolConversion
        render(layout: "application", html: "")
      end
    end
  end
end
