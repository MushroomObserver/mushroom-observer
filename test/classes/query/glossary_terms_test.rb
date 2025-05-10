# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::GlossaryTerms class to be included in QueryTest
class Query::GlossaryTermsTest < UnitTestCase
  include QueryExtensions

  def test_glossary_term_all
    expects = GlossaryTerm.order_by_default
    assert_query(expects, :GlossaryTerm)
  end

  def test_glossary_term_name_has
    expects = [glossary_terms(:multiple_word_glossary_term)]
    scope = GlossaryTerm.name_has("Emarginate")
    assert_query_scope(expects, scope, :GlossaryTerm, name_has: "emarginate")
  end

  def test_glossary_term_description_has
    expects = [glossary_terms(:convex_glossary_term)]
    scope = GlossaryTerm.description_has("Convex")
    assert_query_scope(expects, scope, :GlossaryTerm, description_has: "Convex")
  end

  def test_glossary_term_by_users
    expects = [glossary_terms(:multiple_word_glossary_term)]
    scope = GlossaryTerm.by_users(mary)
    assert_query_scope(expects, scope, :GlossaryTerm, by_users: mary)
  end

  def test_glossary_term_pattern
    assert_query([], :GlossaryTerm, pattern: "no glossary term has this")
    # name
    expects = [glossary_terms(:conic_glossary_term)]
    scope = GlossaryTerm.pattern("Cute little cone head")
    assert_query_scope(expects, scope,
                       :GlossaryTerm, pattern: "Cute little cone head")
    # default description, many expects
    expects = GlossaryTerm.pattern("Description of Term").order_by_default
    assert_query(expects, :GlossaryTerm, pattern: "Description of Term")
    # blank == all
    expects = GlossaryTerm.order_by_default
    assert_query(expects, :GlossaryTerm, pattern: "")
  end
end
