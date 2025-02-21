# frozen_string_literal: true

module Tabs
  module ThemesHelper
    def theme_show_tabs
      [theme_list_tab,
       account_edit_preferences_tab]
    end

    def theme_list_tab
      InternalLink.new(:theme_list.t, theme_color_themes_path).tab
    end
  end
end
