# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::GlossaryTerms class to be included in QueryTest
class Query::GlossaryTermsTest < UnitTestCase
  include QueryExtensions

  def test_glossary_term_all
    expects = GlossaryTerm.index_order
    assert_query(expects, :GlossaryTerm)
  end

  def test_glossary_term_pattern_search
    assert_query([], :GlossaryTerm, pattern: "no glossary term has this")
    # name
    expects = GlossaryTerm.index_order.
              where(GlossaryTerm[:description].matches("%conic_glossary_term%").
                    or(GlossaryTerm[:name].matches("%conic_glossary_term%"))).
              distinct
    assert_query(expects, :GlossaryTerm, pattern: "conic_glossary_term")
    # description
    expects = GlossaryTerm.index_order.
              where(GlossaryTerm[:description].matches("%Description of Term%").
                    or(GlossaryTerm[:name].matches("%Description of Term%"))).
              distinct
    assert_query(expects, :GlossaryTerm, pattern: "Description of Term")
    # blank
    expects = GlossaryTerm.index_order
    assert_query(expects, :GlossaryTerm, pattern: "")
  end
end
