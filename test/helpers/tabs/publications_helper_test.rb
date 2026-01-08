# frozen_string_literal: true

require("test_helper")

module Tabs
  class PublicationsHelperTest < ActionView::TestCase
    include Tabs::PublicationsHelper

    # Regression test for bug where Actions menu displayed "Add [TYPE]"
    # instead of "Add Publication" when type parameter wasn't passed correctly
    def test_new_publication_tab_text_includes_publication
      title, _url, _html_options = new_publication_tab

      # The tab link text should be "Add Publication", not "Add [TYPE]"
      assert_match(/Add Publication/i, title,
                   "Tab should display 'Add Publication' not 'Add [TYPE]'")
      assert_no_match(/\[TYPE\]/i, title,
                      "Tab should not contain the literal text '[TYPE]'")
    end

    def test_new_publication_tab_links_to_new_publication_path
      _title, url, _html_options = new_publication_tab

      assert_match(%r{/publications/new}, url,
                   "Tab should link to new publication path")
    end

    def test_publications_index_tab_text_includes_index
      title, _url, _html_options = publications_index_tab

      assert_match(/Publication List/i, title,
                   "Tab should display 'Publication List'")
    end

    def test_publications_index_tab_links_to_publications_path
      _title, url, _html_options = publications_index_tab

      assert_match(%r{/publications}, url,
                   "Tab should link to publications path")
    end
  end
end
