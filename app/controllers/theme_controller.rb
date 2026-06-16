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

  # Show general information on color themes
  def color_themes
    render(Views::Controllers::Theme::ColorThemes.new)
  end

  # Individual theme actions. Each shows a sample page in that theme,
  # explaining the colors for that theme.
  def Agaricus # rubocop:disable Naming/MethodName
    render(Views::Controllers::Theme::Agaricus.new)
  end

  def Amanita # rubocop:disable Naming/MethodName
    render(Views::Controllers::Theme::Amanita.new)
  end

  def BlackOnWhite # rubocop:disable Naming/MethodName
    render(Views::Controllers::Theme::BlackOnWhite.new)
  end

  def Cantharellaceae # rubocop:disable Naming/MethodName
    render(Views::Controllers::Theme::Cantharellaceae.new)
  end

  def Hygrocybe # rubocop:disable Naming/MethodName
    render(Views::Controllers::Theme::Hygrocybe.new)
  end
end
