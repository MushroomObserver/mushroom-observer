# frozen_string_literal: true

require "test_helper"

class FormErrorsTest < ComponentTestCase
  def test_renders_nothing_when_no_errors
    html = render(Components::Form::Errors.new(model: GlossaryTerm.new))

    assert_equal("", html)
  end

  def test_renders_error_count_and_messages
    term = GlossaryTerm.new
    term.errors.add(:name, :blank)
    html = render(Components::Form::Errors.new(model: term))

    assert_html(html, "#error_explanation.alert-danger")
    assert_html(html, "#error_explanation h2")
    assert_html(html, "#error_explanation ul li")
    error_text = Nokogiri::HTML(html).at_css("#error_explanation").text
    assert_includes(error_text, "1 #{:error.t}")
    assert_includes(
      error_text, :errors_prohibited_save.t(type: term.type_tag.ti)
    )
    assert_match(/Name can.{1,6}t be blank/, error_text)
  end

  def test_pluralizes_error_count_for_multiple_errors
    term = GlossaryTerm.new
    term.errors.add(:name, :blank)
    term.errors.add(:base, :invalid)
    html = render(Components::Form::Errors.new(model: term))

    error_text = Nokogiri::HTML(html).at_css("#error_explanation").text
    assert_includes(error_text, "2 #{:errors.t}")
  end
end
