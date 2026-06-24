# frozen_string_literal: true

require("test_helper")

# Parity harness for the help-note / help-block sweep.
# Each LegacyX class mirrors the raw Phlex element calls that existed
# before conversion; the matching NewX class uses the component.
# assert_html_element_equivalent confirms the rendered DOM is identical.
class HelpSweepParityTest < ComponentTestCase
  # ----- Help::Note span (default element) ----

  def test_note_span_with_block_content
    assert_parity(
      render(LegacyNoteSpan.new),
      render(NewNoteSpan.new),
      label: "note_span"
    )
  end

  def test_note_span_string_arg
    assert_parity(
      render(LegacyNoteSpanString.new),
      render(NewNoteSpanString.new),
      label: "note_span_string"
    )
  end

  # ----- Help::Note div (explicit element) ----

  def test_note_div_with_block_content
    assert_parity(
      render(LegacyNoteDiv.new),
      render(NewNoteDiv.new),
      label: "note_div"
    )
  end

  # ----- Help::Note with extra class ----

  def test_note_extra_class
    assert_parity(
      render(LegacyNoteExtraClass.new),
      render(NewNoteExtraClass.new),
      label: "note_extra_class"
    )
  end

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

  class LegacyNoteSpan < Components::Base
    def view_template
      span(class: "help-note") { plain("Help text") }
    end
  end

  class LegacyNoteSpanString < Components::Base
    def view_template
      span(class: "help-note") { trusted_html("Help <b>text</b>") }
    end
  end

  class LegacyNoteDiv < Components::Base
    def view_template
      div(class: "help-note") { plain("Help text") }
    end
  end

  class LegacyNoteExtraClass < Components::Base
    def view_template
      div(class: "help-note mt-2 mb-5") { plain("Help text") }
    end
  end

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

  class NewNoteSpan < Components::Base
    def view_template
      render(::Components::Help::Note.new) { plain("Help text") }
    end
  end

  class NewNoteSpanString < Components::Base
    def view_template
      render(::Components::Help::Note.new) { trusted_html("Help <b>text</b>") }
    end
  end

  class NewNoteDiv < Components::Base
    def view_template
      render(::Components::Help::Note.new(:div)) { plain("Help text") }
    end
  end

  class NewNoteExtraClass < Components::Base
    def view_template
      render(::Components::Help::Note.new(:div, class: "mt-2 mb-5")) do
        plain("Help text")
      end
    end
  end

  class NewBlockDiv < Components::Base
    def view_template
      render(::Components::Help::Block.new) { plain("Help text") }
    end
  end

  class NewBlockDivString < Components::Base
    def view_template
      render(::Components::Help::Block.new) { trusted_html("Help <b>text</b>") }
    end
  end

  class NewBlockP < Components::Base
    def view_template
      render(::Components::Help::Block.new(:p)) { plain("Help text") }
    end
  end

  class NewBlockExtraClass < Components::Base
    def view_template
      render(::Components::Help::Block.new(class: "mt-4")) { plain("Help text") }
    end
  end
end
