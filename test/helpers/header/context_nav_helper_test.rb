# frozen_string_literal: true

require("test_helper")

# test the application-wide helpers
module Header
  class ContextNavHelperTest < ActionView::TestCase
    include LinkHelper

    # Test that add_context_nav handles nil links gracefully
    def test_add_context_nav_with_nil_links
      # This should not raise an error
      assert_nothing_raised do
        add_context_nav(nil)
      end
      # Should not add context_nav content
      assert_nil(content_for(:context_nav))
    end

    # Test that add_context_nav handles empty array gracefully
    def test_add_context_nav_with_empty_links
      # This should not raise an error
      assert_nothing_raised do
        add_context_nav([])
      end
      # Should not add context_nav content
      assert_nil(content_for(:context_nav))
    end

    # destroy_button tab tested in articles_controller_test
    # That method calls `add_q_param` and others unavailable to helper tests
    # put_button is not used for articles, but we're just testing HTML output
    def test_context_nav_dropdown
      article = Article.last
      links = [["Create Article", new_article_path,
                { class: "new_article_link" }],
               [:EDIT.t, edit_article_path(article.id),
                { class: "edit_article_link" }],
               ["merge", article_path(article.id), { button: :put }],
               ["move", article_path(article.id), { button: :patch }],
               ["celebrate", article_path(article.id), { button: :post }]]

      tabs = context_nav_links(links)

      tab1 = link_to(
        "Create Article", new_article_path, { class: "new_article_link" }
      )
      tab2 = link_to(
        :EDIT.t, edit_article_path(article.id), { class: "edit_article_link" }
      )
      tab3 = put_button(name: "merge", path: article_path(article.id))
      tab4 = patch_button(name: "move", path: article_path(article.id))
      tab5 = button_to("celebrate", article_path(article.id))

      assert_includes(tabs, tab1)
      assert_includes(tabs, tab2)
      assert_includes(tabs, tab3)
      assert_includes(tabs, tab4)
      assert_includes(tabs, tab5)
    end
  end
end
