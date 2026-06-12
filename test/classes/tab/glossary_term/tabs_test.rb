# frozen_string_literal: true

require("test_helper")

# Covers all 3 Tab::GlossaryTerm::* single Tab POROs (Show, Index,
# Edit). The Return / Object::Return tab is exercised in
# CollectionsTest via FormEdit / ImageForm.
module Tab::GlossaryTerm
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @term = glossary_terms(:conic_glossary_term)
    end

    def test_show
      tab = Tab::GlossaryTerm::Show.new(term: @term)

      assert_equal(:show_glossary_term.t(glossary_term: @term.name),
                   tab.title)
      assert_equal(routes.glossary_term_path(@term.id), tab.path)
      assert_includes(tab.html_options[:class], "glossary_term_link")
    end

    def test_index
      tab = Tab::GlossaryTerm::Index.new

      assert_equal(:glossary_term_index.t, tab.title)
      assert_equal(routes.glossary_terms_path, tab.path)
      assert_includes(tab.html_options[:class], "glossary_terms_index_link")
    end

    def test_edit
      tab = Tab::GlossaryTerm::Edit.new(term: @term)

      assert_equal(:edit_glossary_term.t, tab.title)
      assert_equal(routes.edit_glossary_term_path(@term.id), tab.path)
      assert_includes(tab.html_options[:class], "edit_glossary_term_link")
    end
  end
end
