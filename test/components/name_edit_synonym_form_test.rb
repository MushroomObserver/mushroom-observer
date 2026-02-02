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

    # The label should contain IN ORDER: checkbox, link, (id)
    # Pattern: <label...><input type="checkbox"...><a href="...">Name</a> (id)</label>
    label_pattern = /<label[^>]*>.*?
      <input[^>]*type="checkbox"[^>]*>.*?
      <a\s+href="\/names\/#{@synonym1.id}"[^>]*>.*?<\/a>\s*
      \(#{@synonym1.id}\)
    /mx
    assert_match(label_pattern, html,
                 "Label should contain checkbox, then link, then (id)")
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
