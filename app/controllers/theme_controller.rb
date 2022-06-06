# frozen_string_literal: true

# Theme controller
# Shows information about available user color themes.
#
#  ==== Public Actions =====
#  color_themes::       Show general information about color themes
#  Agaricus, etc.::     Show sample page, explaining color derivation.
#
class ThemeController < ApplicationController
  # callbacks
  before_action :login_required
  # except: MO.themes + [:color_themes]
  before_action :disable_link_prefetching

  # Show general information on color themes
  def color_themes
  end

  # Individual theme actions. Each shows a sample page in that theme,
  # explaining the colors for that theme.
  # These actions are not defined here, but rather are automagically created
  # if there's a view template corresponding to the theme.
end
