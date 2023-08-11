# frozen_string_literal: true

module Tabs
  module ThemesHelper
    def theme_show_links
      [
        [:theme_list.t, theme_color_themes_path, { class: "theme_list_link" }],
        account_edit_preferences_link
      ]
    end
  end
end
