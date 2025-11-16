# frozen_string_literal: true

require "test_helper"

class GlossaryTermFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @glossary_term = GlossaryTerm.new
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_name_field
    form = render_form

    assert_includes(form, :glossary_term_name.l)
    assert_includes(form, 'name="glossary_term[name]"')
    assert_includes(form, "data-autofocus")
  end

  def test_renders_form_with_description_field
    form = render_form

    assert_includes(form, :glossary_term_description.l)
    assert_includes(form, 'name="glossary_term[description]"')
    assert_includes(form, "rows=\"16\"")
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :SAVE.t)
    assert_includes(form, "btn btn-default")
    assert_includes(form, "center-block my-3")
  end

  def test_form_has_correct_attributes_for_new_record
    form = render_form

    assert_includes(form, 'action="/glossary_terms"')
    assert_includes(form, 'method="post"')
  end

  def test_form_has_correct_attributes_for_existing_record
    @glossary_term = glossary_terms(:conic_glossary_term)
    form = render_form

    assert_includes(form, "action=\"/glossary_terms/#{@glossary_term.id}\"")
    assert_includes(form, 'name="_method"')
    assert_includes(form, 'value="patch"')
  end

  def test_renders_help_text_in_append_slots
    form = render_form

    # Name field help text (check for substring to avoid HTML escaping issues)
    assert_includes(form, "A mycology-specific term")
    assert_includes(form, "all lower-case except if capitalized")

    # Description field help text
    assert_includes(form, "A concise definition matching the part of speech")
    assert_includes(form, "without repeating another")

    # Textile link (contains HTML)
    assert_includes(form, "This field can be formatted with")
    assert_includes(form, "Textile</a>")

    # Glossary documentation link (appears in both fields)
    assert_includes(form, "Documentation and Guidelines")
    assert_includes(
      form,
      "https://github.com/MushroomObserver/mushroom-observer/blob/main/doc/glossary.md"
    )
  end

  private

  def render_form
    form = Components::GlossaryTermForm.new(@glossary_term)
    render(form)
  end
end
