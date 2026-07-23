# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Names::Classification::Inherit
  class FormTest < ComponentTestCase
    def test_form_structure
      name = names(:coprinus_comatus)
      html = render_form(name: name)

      # Form structure and action
      assert_html(html, "form#name_classification_inherit_form")
      assert_html(html,
                  "form[action*='/names/#{name.id}/classification/inherit']")
      assert_html(html, "button[type='submit']", text: :submit.ti)

      # Parent name text field
      assert_html(html, "input[name='inherit_classification[parent]']")
      assert_includes(html, :inherit_classification_parent_name.l)
    end

    def test_form_with_candidates
      name = names(:coprinus_comatus)
      candidates = [names(:agaricus_campestris), names(:boletus_edulis)]
      html = render_form(
        name: name,
        candidates: candidates,
        message: :inherit_classification_multiple_matches
      )

      # Warning alert with radio options
      assert_html(html, "div.alert-warning")
      candidates.each do |c|
        assert_html(html, "input[type='radio'][value='#{c.id}']")
      end
    end

    private

    def render_form(name:, parent: nil, candidates: nil, message: nil)
      render(Form.new(
               name: name,
               parent: parent,
               candidates: candidates,
               message: message
             ))
    end
  end
end
