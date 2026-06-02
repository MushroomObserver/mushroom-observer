# frozen_string_literal: true

# Action-nav for the theme show page (a color-theme preview).
class Tab::Theme::ShowActions < Tab::Collection
  private

  def tabs
    [Tab::Theme::List.new,
     Tab::Account::EditPreferences.new]
  end
end
