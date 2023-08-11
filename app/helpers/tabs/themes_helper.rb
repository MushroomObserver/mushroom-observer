# frozen_string_literal: true

module Tabs
  module ThemesHelper
    def theme_show_links
      [
        [:theme_list.t, theme_color_themes_path, { class: "theme_list_link" }],
        [:app_preferences.t, edit_account_preferences_path,
         { class: "edit_account_preferences_link" }]
      ]
    end
  end
end
