# frozen_string_literal: true

require("test_helper")

# test the application-wide helpers
class TitleAndTabsetHelperTest < ActionView::TestCase
  include LinkHelper

  def test_title_tag_contents
    # Prove that if @title is present, <title> contents are @title
    title = "@title present"
    action_name = "something_else"
    assert_equal(title,
                 title_tag_contents(title: title, action: action_name))

    # Prove that if @title is absent,
    # and there's an en.txt label for :title_for_action_name,
    # then <title> contents are the translation for that label
    title = ""
    action_name = "user_search"
    assert_equal("User Search",
                 title_tag_contents(title: title, action: action_name))

    # Prove that if @title is absent,
    # and no en.txt label for :title_for_action_name,
    # then <title> contents are action name humanized
    title = ""
    action_name = "blah_blah"
    assert_equal("Blah Blah",
                 title_tag_contents(title: title, action: action_name))
  end

  # destroy_button tab tested in articles_controller_test
  # That method calls `add_query_param` and others unavailable to helper tests
  # put_button is not used for articles, but we're just testing HTML output
  def test_create_links_to
    article = Article.last
    links = [[:create_article_title.t, new_article_path,
              { class: "new_article_link" }],
             [:EDIT.t, edit_article_path(article.id),
              { class: "edit_article_link" }],
             ["merge", article_path(article.id), { button: :put }],
             ["move", article_path(article.id), { button: :patch }],
             ["celebrate", article_path(article.id), { button: :post }]]

    tabs = create_links_to(links)

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
