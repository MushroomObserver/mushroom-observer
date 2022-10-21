# frozen_string_literal: true

class Admin::ChangeBannerController < ApplicationController
  include Admin::RestrictAccess

  before_action :login_required

  # Update banner across all translations.
  def new
    @val = :app_banner_box.l.to_s
  end

  def create
    @val = params[:val].to_s.strip
    @val = "X" if @val.blank?
    update_banner_languages
    redirect_to("/")
  end

  private

  def update_banner_languages
    time = Time.zone.now
    Language.all.includes([:translation_strings]).each do |lang|
      if (str = lang.translation_strings.where(tag: "app_banner_box")[0])
        update_banner_string(str, time)
      else
        str = create_banner_string(lang, time)
      end
      str.update_localization
      str.language.update_localization_file
      str.language.update_export_file
    end
  end

  def update_banner_string(str, time)
    str.update!(
      text: @val,
      updated_at: (str.language.official ? time : time - 1.minute)
    )
  end

  def create_banner_string(lang, time)
    lang.translation_strings.create!(
      tag: "app_banner_box",
      text: @val,
      updated_at: time - 1.minute
    )
  end
end
