# frozen_string_literal: true

require("test_helper")

# test the application-wide helpers
class TitleContextNavHelperTest < ActionView::TestCase
  include LinkHelper

  # destroy_button tab tested in articles_controller_test
  # That method calls `add_query_param` and others unavailable to helper tests
  # put_button is not used for articles, but we're just testing HTML output
  def test_context_nav_dropdown
    article = Article.last
    links = [[:create_article_title.t, new_article_path,
              { class: "new_article_link" }],
             [:EDIT.t, edit_article_path(article.id),
              { class: "edit_article_link" }],
             ["merge", article_path(article.id), { button: :put }],
             ["move", article_path(article.id), { button: :patch }],
             ["celebrate", article_path(article.id), { button: :post }]]

    tabs = context_nav_dropdown(links)

    tab1 = link_to(
      :create_article_title.t, new_article_path, { class: "new_article_link" }
    )
    tab2 = link_to(
      :EDIT.t, edit_article_path(article.id), { class: "edit_article_link" }
    )
    tab3 = put_button(name: "merge", path: article_path(article.id))
    tab4 = patch_button(name: "move", path: article_path(article.id))
    tab5 = post_button(name: "celebrate", path: article_path(article.id))

    assert_includes(tabs, tab1)
    assert_includes(tabs, tab2)
    assert_includes(tabs, tab3)
    assert_includes(tabs, tab4)
    assert_includes(tabs, tab5)
  end
end
