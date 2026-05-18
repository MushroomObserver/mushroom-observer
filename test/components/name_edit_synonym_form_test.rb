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

    # The label for @synonym1 should contain IN ORDER:
    # checkbox, link, id badge.
    doc = Nokogiri::HTML(html)
    label = doc.css("label").find do |lbl|
      lbl.at_css("a[href='/names/#{@synonym1.id}']")
    end
    assert(label, "Expected a label containing the synonym link")

    types = label.css("input[type='checkbox'], a, button").map(&:name)
    assert_equal(%w[input a button], types,
                 "Label should contain checkbox, then link, then id badge")
    assert_html(label.to_html, "a[href='/names/#{@synonym1.id}']")
    assert_html(label.to_html, "button.badge",
                text: @synonym1.id.to_s)
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
