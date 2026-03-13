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

    # The label should contain IN ORDER: checkbox, link, id badge
    label_pattern = %r{<label[^>]*>.*?
      <input[^>]*type="checkbox"[^>]*>.*?
      <a\s+href="/names/#{@synonym1.id}"[^>]*>.*?</a>\s*
      <button[^>]*class="[^"]*badge[^"]*"[^>]*>#{@synonym1.id}</button>
    }mx
    assert_match(label_pattern, html,
                 "Label should contain checkbox, then link, then id badge")
  end

  def test_proposed_synonyms_have_same_label_format
    proposed = names(:coprinus_comatus)
    html = render_form(
      current_synonyms: [@name],
      proposed_synonyms: [proposed]
    )

    # Proposed synonym should have link and ID badge
    assert_html(html, "a[href='/names/#{proposed.id}']")
    assert_html(html, "button.badge-id", text: proposed.id.to_s)
  end

  private

  def render_form(current_synonyms: [], proposed_synonyms: [], new_names: [],
                  synonym_members: "", deprecate_all: true)
    render(Components::NameEditSynonymForm.new(
             name: @name,
             synonym_members: synonym_members,
             deprecate_all: deprecate_all,
             current_synonyms: current_synonyms,
             proposed_synonyms: proposed_synonyms,
             new_names: new_names
           ))
  end
end
