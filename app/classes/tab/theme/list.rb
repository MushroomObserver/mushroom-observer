# frozen_string_literal: true

# "Browse color themes" link.
class Tab::Theme::List < Tab::Base
  def title
    :theme_list.t
  end

  def path
    theme_color_themes_path
  end
end
