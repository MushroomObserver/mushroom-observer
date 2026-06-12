# frozen_string_literal: true

require("test_helper")

class GlossaryTermsHelperTest < ActionView::TestCase
  include GlossaryTermsHelper
  include LinkHelper

  def test_glossary_term_destroy_button
    term = glossary_terms(:conic_glossary_term)

    html = glossary_term_destroy_button(term)
    doc = Nokogiri::HTML(html)

    assert(doc.at_css("form[action='#{glossary_term_path(term.id)}']"),
           "Expected form targeting the glossary term destroy path")
    assert(doc.at_css("button"),
           "Expected a button element inside the destroy form")
  end
end
