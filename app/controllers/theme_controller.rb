# Theme controller
class ThemeController < ApplicationController
  # callbacks
  before_action :login_required, except: MO.themes + [
    :color_themes,
  ]
  before_action :disable_link_prefetching

  # Displays info on color themes.
  def color_themes # :nologin:
  end
end
