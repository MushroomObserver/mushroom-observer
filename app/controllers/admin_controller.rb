# frozen_string_literal: true

class AdminController < ApplicationController
  before_action :login_required

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

  # Simple list of all the files in public/html that are linked to the W3C
  # validator to make testing easy.
  def w3c_tests
    render(layout: false)
  end

  # Update banner across all translations.
  def change_banner
    if !in_admin_mode?
      flash_error(:permission_denied.t)
      redirect_to("/")
    elsif request.method == "POST"
      @val = params[:val].to_s.strip
      @val = "X" if @val.blank?
      time = Time.zone.now
      Language.all.each do |lang|
        if (str = lang.translation_strings.where(tag: "app_banner_box")[0])
          str.update!(
            text: @val,
            updated_at: (str.language.official ? time : time - 1.minute)
          )
        else
          str = lang.translation_strings.create!(
            tag: "app_banner_box",
            text: @val,
            updated_at: time - 1.minute
          )
        end
        str.update_localization
        str.language.update_localization_file
        str.language.update_export_file
      end
      redirect_to("/")
    else
      @val = :app_banner_box.l.to_s
    end
  end
end
