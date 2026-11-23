# frozen_string_literal: true

require "test_helper"

class LocalizationTest < ComponentTestCase
  class AppendColonHost < Components::Base
    prop :space, _Boolean, default: true

    def view_template
      plain(append_colon("Label", space: @space))
    end
  end

  def test_append_colon_defaults_to_trailing_space
    html = render(AppendColonHost.new)

    assert_includes(html, "Label: ")
  end

  def test_append_colon_space_false_omits_trailing_space
    html = render(AppendColonHost.new(space: false))

    assert_includes(html, "Label:")
    assert_not_includes(html, "Label: ")
  end
end
