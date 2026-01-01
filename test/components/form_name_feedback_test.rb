# frozen_string_literal: true

require "test_helper"

class FormNameFeedbackTest < ComponentTestCase

  def setup
    super
  end

  def test_renders_parent_deprecated_warning
    parent = names(:lactarius)
    html = render_feedback(
      given_name: "Test species",
      names: [names(:agaricus_campestris)],
      valid_names: [names(:coprinus_comatus)],
      parent_deprecated: parent
    )

    assert_html(html, "#name_messages")
    assert_html(html, ".alert-warning")
  end

  def test_renders_not_recognized_error_when_names_empty
    html = render_feedback(
      given_name: "Unknown name",
      names: []
    )

    assert_html(html, "#name_messages")
    assert_html(html, ".alert-danger")
  end

  def test_renders_deprecated_warning_with_valid_synonyms
    html = render_feedback(
      given_name: "Deprecated name",
      names: [names(:agaricus_campestris)],
      valid_names: [names(:coprinus_comatus)]
    )

    assert_html(html, "#name_messages")
    assert_html(html, ".alert-warning")
  end

  def test_renders_multiple_names_error
    html = render_feedback(
      given_name: "Ambiguous",
      names: [names(:agaricus_campestris), names(:coprinus_comatus)]
    )

    assert_html(html, "#name_messages")
    assert_html(html, ".alert-danger")
  end

  private

  def render_feedback(given_name:, names: nil, valid_names: nil,
                      parent_deprecated: nil, suggest_corrections: false)
    component = Components::FormNameFeedback.new(
      given_name: given_name,
      button_name: "Create",
      names: names,
      valid_names: valid_names,
      suggest_corrections: suggest_corrections,
      parent_deprecated: parent_deprecated
    )
    render(component)
  end
end
