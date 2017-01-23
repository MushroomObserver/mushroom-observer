require "test_helper"

# Test theme controller
class ObserverControllerTest
  # Prove color_themes succeeds.  (It simply dispays a text page.)
  def test_color_themes
    get(:color_themes)
    assert_response(:success)
  end
end
