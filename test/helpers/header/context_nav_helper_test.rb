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
      tab3 = render(Components::CrudButton::Put.new(
                      name: "merge", target: article_path(article.id)
                    ))
      tab4 = render(Components::CrudButton::Patch.new(
                      name: "move", target: article_path(article.id)
                    ))
      tab5 = button_to("celebrate", article_path(article.id))

      assert_includes(tabs, tab1)
      assert_includes(tabs, tab2)
      assert_includes(tabs, tab3)
      assert_includes(tabs, tab4)
      assert_includes(tabs, tab5)
    end

    # add_context_nav accepts a single Tab::Base — the foundational
    # Tab POROs PR's promise to the helpers-to-POROs migration.
    def test_add_context_nav_with_tab_base
      project = projects(:bolete_project)
      add_context_nav(Tab::Project::Summary.new(project: project))

      assert_not_nil(content_for(:context_nav))
    end

    # add_context_nav accepts a Tab::Collection — Collections are
    # Enumerable, so the helper iterates and calls #to_a on each.
    def test_add_context_nav_with_tab_collection
      project = projects(:bolete_project)
      collection = Tab::Project::AdminSubtabs.new(project: project)
      add_context_nav(collection)

      assert_not_nil(content_for(:context_nav))
    end

    # Legacy Array of [text, url, args] tuples still works
    # (backwards compat for existing helpers/tabs/* callers).
    def test_add_context_nav_with_legacy_array
      add_context_nav([["Foo", "/foo", { class: "foo_link" }]])

      assert_not_nil(content_for(:context_nav))
    end
  end
end
