# frozen_string_literal: true

require "test_helper"

class NameInheritClassificationFormTest < ComponentTestCase
  def test_form_structure
    name = names(:coprinus_comatus)
    html = render_form(name: name)

    # Form structure and action
    assert_html(html, "form#name_inherit_classification_form")
    assert_html(html,
                "form[action*='/names/#{name.id}/classification/inherit']")
    assert_html(html, "input[type='submit'][value='#{:SUBMIT.l}']")

    # Parent name text field
    assert_html(html, "input[name='inherit_classification[parent]']")
    assert_includes(html, :inherit_classification_parent_name.l)
  end

  def test_form_with_options
    name = names(:coprinus_comatus)
    options = [names(:agaricus_campestris), names(:boletus_edulis)]
    html = render_form(
      name: name,
      options: options,
      message: :inherit_classification_multiple_matches
    )

    # Warning alert with radio options
    assert_html(html, "div.alert-warning")
    options.each do |opt|
      assert_html(html, "input[type='radio'][value='#{opt.id}']")
    end
  end

  private

  def render_form(name:, parent: nil, options: nil, message: nil)
    render(Components::NameInheritClassificationForm.new(
             name: name,
             parent: parent,
             options: options,
             message: message
           ))
  end
end
