# frozen_string_literal: true

require "test_helper"

class NameApproveSynonymFormTest < ComponentTestCase
  def test_form_structure
    name = names(:lactarius_alpinus)
    html = render_form(name: name)

    # Form structure and action
    assert_html(html, "form#name_approve_synonym_form")
    assert_html(html, "form[action*='/names/#{name.id}/synonyms/approve']")
    assert_html(html, "input[type='submit'][value='#{:APPROVE.l}']")

    # Comment textarea
    assert_html(html, "textarea[name='approve_synonym[comment]']")
    assert_includes(html, :name_approve_comments.l)

    # Help text (check that the div is present)
    assert_html(html, "div.help-note")
  end

  def test_form_with_approved_names
    name = names(:lactarius_alpinus)
    approved = [names(:agaricus_campestris), names(:coprinus_comatus)]
    html = render_form(name: name, approved_names: approved)

    # Deprecate others checkbox
    assert_html(html, "input[type='checkbox']" \
                      "[name='approve_synonym[deprecate_others]']")
    assert_includes(html, :name_approve_deprecate.l)

    # Approved names displayed (as HTML with formatting)
    approved.each do |n|
      assert_includes(html, n.display_name.t)
    end
  end

  private

  def render_form(name:, approved_names: nil)
    model = FormObject::ApproveSynonym.new
    render(Components::NameApproveSynonymForm.new(
             model, name: name, approved_names: approved_names
           ))
  end
end
