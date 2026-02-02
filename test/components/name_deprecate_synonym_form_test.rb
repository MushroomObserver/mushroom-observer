# frozen_string_literal: true

require "test_helper"

class NameDeprecateSynonymFormTest < ComponentTestCase
  def test_form_structure
    name = names(:agaricus_campestris)
    html = render_form(name: name)

    # Form structure and action
    assert_html(html, "form#name_deprecate_synonym_form")
    assert_html(html, "form[action*='/names/#{name.id}/synonyms/deprecate']")
    assert_html(html, "input[type='submit'][value='#{:SUBMIT.l}']")

    # Proposed name autocompleter
    assert_html(html, "input[name='deprecate_synonym[proposed_name]']")
    assert_includes(html, :name_deprecate_preferred.l)

    # Misspelling checkbox
    assert_html(html, "input[type='checkbox']" \
                      "[name='deprecate_synonym[is_misspelling]']")
    assert_includes(html, :form_names_misspelling.l)

    # Comment textarea
    assert_html(html, "textarea[name='deprecate_synonym[comment]']")
    assert_includes(html, :name_deprecate_comments.l)
  end

  private

  def render_form(name:, context: {})
    model = FormObject::DeprecateSynonym.new
    render(Components::NameDeprecateSynonymForm.new(
             model, name: name, context: context
           ))
  end
end
