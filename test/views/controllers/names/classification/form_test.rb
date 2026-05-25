# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Names::Classification
  class FormTest < ComponentTestCase
    def test_form_structure
      name = names(:coprinus_comatus)
      html = render_form(name)

      # Form structure and action
      assert_html(html, "form#name_classification_form")
      assert_html(html, "form[action*='/names/#{name.id}/classification']")
      assert_html(html, "input[type='submit'][value='#{:SAVE.l}']")

      # Classification textarea
      assert_html(html, "textarea[name='name[classification]']")
      assert_includes(html, :form_names_classification.l)

      # Help text with rank
      rank = :"rank_#{name.rank.to_s.downcase}".l
      assert_includes(html, :form_names_classification_help.t(rank: rank))
    end

    private

    def render_form(name)
      render(Form.new(name))
    end
  end
end
