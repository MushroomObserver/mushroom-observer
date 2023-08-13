# frozen_string_literal: true

module Tabs
  module ThemesHelper
    def theme_show_links
      [theme_list_link,
        account_edit_preferences_link]
    end

    def theme_list_link
      [:theme_list.t, theme_color_themes_path, { class: __method__.to_s }]
    end
  end
end
