# frozen_string_literal: true

require "test_helper"

class NameEditSynonymFormTest < ComponentTestCase
  def setup
    super
    @name = names(:lepiota_rachodes)
    @synonym1 = names(:chlorophyllum_rachodes)
    @synonym2 = names(:macrolepiota_rachodes)
  end

  def test_synonym_checkbox_label_format
    html = render_form(
      current_synonyms: [@name, @synonym1, @synonym2]
    )

    # Should have checkboxes for synonyms (not the main name)
    assert_html(html, "input[type='checkbox']" \
                      "[name='edit_synonym[existing_synonyms]" \
                      "[#{@synonym1.id}]']")

    # Label should contain link to the name
    assert_html(html, "a[href='/names/#{@synonym1.id}']")

    # Label should show display name (with formatting) and ID in parentheses
    # The display_name.t includes HTML italics, so check for key parts
    assert_includes(html, "(#{@synonym1.id})")
    assert_includes(html, "(#{@synonym2.id})")
  end

  def test_synonym_link_text_contains_display_name
    html = render_form(
      current_synonyms: [@name, @synonym1]
    )

    # The link should contain the formatted display name
    # Check that the link exists with the name's display content
    assert_html(html, "a[href='/names/#{@synonym1.id}']")

    # The label wrapper should contain both the link and the ID
    display_name = Regexp.escape(@synonym1.display_name.t)
    label_pattern = /#{display_name}.*\(#{@synonym1.id}\)/m
    assert_match(label_pattern, html)
  end

  def test_proposed_synonyms_have_same_label_format
    proposed = names(:coprinus_comatus)
    html = render_form(
      current_synonyms: [@name],
      proposed_synonyms: [proposed]
    )

    # Proposed synonym should have link and ID
    assert_html(html, "a[href='/names/#{proposed.id}']")
    assert_includes(html, "(#{proposed.id})")
  end

  private

  def render_form(current_synonyms: [], proposed_synonyms: [], new_names: [],
                  list_members: "", deprecate_all: true)
    model = FormObject::EditSynonym.new(
      synonym_members: list_members,
      deprecate_all: deprecate_all
    )
    render(Components::NameEditSynonymForm.new(
             model,
             name: @name,
             context: {
               current_synonyms: current_synonyms,
               proposed_synonyms: proposed_synonyms,
               new_names: new_names,
               list_members: list_members,
               deprecate_all: deprecate_all
             }
           ))
  end
end
