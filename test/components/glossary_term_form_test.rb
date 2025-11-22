# frozen_string_literal: true

require "test_helper"

class GlossaryTermFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @glossary_term = GlossaryTerm.new
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_name_field
    assert_includes(@html, :glossary_term_name.l)
    assert_html(@html, "input[name='glossary_term[name]']")
    assert_html(@html, "input[data-autofocus]")
  end

  def test_renders_form_with_description_field
    assert_includes(@html, :glossary_term_description.l)
    assert_html(@html, "textarea[name='glossary_term[description]']")
    assert_html(@html, "textarea[rows='16']")
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SAVE.t}']")
    assert_html(@html, ".btn.btn-default")
    assert_html(@html, ".center-block.my-3")
  end

  def test_form_has_correct_attributes_for_new_record
    assert_html(@html, "form[action='/glossary_terms']")
    assert_html(@html, "form[method='post']")
  end

  def test_form_has_correct_attributes_for_existing_record
    @glossary_term = glossary_terms(:conic_glossary_term)
    html = render_form

    assert_html(html, "form[action='/glossary_terms/#{@glossary_term.id}']")
    assert_html(html, "input[name='_method']")
    assert_html(html, "input[value='patch']")
  end

  def test_renders_help_text_in_append_slots
    # Name field help text (check for substring to avoid HTML escaping issues)
    assert_includes(@html, "A mycology-specific term")
    assert_includes(@html, "all lower-case except if capitalized")

    # Description field help text
    assert_includes(@html, "A concise definition matching the part of speech")
    assert_includes(@html, "without repeating another")

    # Textile link (contains HTML)
    assert_includes(@html, "This field can be formatted with")
    assert_includes(@html, "Textile</a>")

    # Glossary documentation link (appears in both fields)
    assert_includes(@html, "Documentation and Guidelines")
    assert_includes(
      @html,
      "https://github.com/MushroomObserver/mushroom-observer/blob/main/doc/glossary.md"
    )
  end

  private

  def render_form
    form = Components::GlossaryTermForm.new(@glossary_term)
    render(form)
  end
end
