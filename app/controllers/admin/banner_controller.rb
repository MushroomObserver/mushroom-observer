# frozen_string_literal: true

module Admin
  class BannerController < AdminController
    # Update banner across all translations.
    def edit
      @val = h(:app_banner_box.l.to_s)
    end

    def update
      @val = params[:val].to_s.strip
      @val = "X" if @val.blank?
      update_banner_languages
      render(:edit)
    end

    private

    def update_banner_languages
      time = Time.zone.now
      Language.includes([:translation_strings]).each do |lang|
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
end
