# frozen_string_literal: true

require("test_helper")

# Parity harness for the help-block sweep.
# Each LegacyX class mirrors the raw Phlex element calls that existed
# before conversion; the matching NewX class uses the component.
# assert_html_element_equivalent confirms the rendered DOM is identical.
#
# The original version of this file also covered a "help-note" flavor
# (`Components::Help::Note`, later merged into `Components::Help`).
# That parity coverage was dropped here, but the two classes are NOT
# interchangeable: `.help-note` stays genuinely inline (color only),
# while `.help-block` is Bootstrap's own class and hardcodes
# `display: block`. `Help(element: :span, ...)` renders `.help-note`
# for exactly this reason — see `Components::Help`'s doc comment and
# `test/components/help_test.rb`'s `element: :span` coverage.
class HelpSweepParityTest < ComponentTestCase
  # ----- Help::Block div (default element) ----

  def test_block_div_with_block_content
    assert_parity(
      render(LegacyBlockDiv.new),
      render(NewBlockDiv.new),
      label: "block_div"
    )
  end

  def test_block_div_string_arg
    assert_parity(
      render(LegacyBlockDivString.new),
      render(NewBlockDivString.new),
      label: "block_div_string"
    )
  end

  # ----- Help::Block paragraph (explicit element) ----

  def test_block_paragraph
    assert_parity(
      render(LegacyBlockP.new),
      render(NewBlockP.new),
      label: "block_paragraph"
    )
  end

  # ----- Help::Block with extra class ----

  def test_block_extra_class
    assert_parity(
      render(LegacyBlockExtraClass.new),
      render(NewBlockExtraClass.new),
      label: "block_extra_class"
    )
  end

  private

  def assert_parity(legacy_html, new_html, label:)
    assert_html_element_equivalent(
      "<div id='parity'>#{legacy_html}</div>",
      "<div id='parity'>#{new_html}</div>",
      selector: "#parity",
      label: label
    )
  end

  # ---- Legacy (raw element) versions ----

  class LegacyBlockDiv < Components::Base
    def view_template
      div(class: "help-block") { plain("Help text") }
    end
  end

  class LegacyBlockDivString < Components::Base
    def view_template
      div(class: "help-block") { trusted_html("Help <b>text</b>") }
    end
  end

  class LegacyBlockP < Components::Base
    def view_template
      p(class: "help-block") { plain("Help text") }
    end
  end

  class LegacyBlockExtraClass < Components::Base
    def view_template
      div(class: "help-block mt-4") { plain("Help text") }
    end
  end

  # ---- New (component) versions ----

  class NewBlockDiv < Components::Base
    def view_template
      render(::Components::Help.new) { plain("Help text") }
    end
  end

  class NewBlockDivString < Components::Base
    def view_template
      render(::Components::Help.new) { trusted_html("Help <b>text</b>") }
    end
  end

  class NewBlockP < Components::Base
    def view_template
      render(::Components::Help.new(element: :p)) { plain("Help text") }
    end
  end

  class NewBlockExtraClass < Components::Base
    def view_template
      render(::Components::Help.new(class: "mt-4")) { plain("Help text") }
    end
  end
end
