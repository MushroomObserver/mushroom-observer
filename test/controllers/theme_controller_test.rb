# frozen_string_literal: true

require "test_helper"

# Test theme controller
class ThemeControllerTest < FunctionalTestCase
  # Prove color_themes action succeeds.
  def test_color_themes
    get(:color_themes)
    assert_response(:success)
  end

  def test_individual_themes
    MO.themes.each do |theme|
      get(theme)
      assert_response(:success)
    end
  end
end
