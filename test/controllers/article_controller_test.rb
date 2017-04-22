require "test_helper"

# Controller tests for news articles
class ArticleControllerTest < FunctionalTestCase
  # ----------------------------
  #  Create article
  # ----------------------------
  def test_create_article_get
    # Prove user cannot see article form unless in admin mode
    user = users(:rolf)
    login(user.login)
    error = assert_raises(RuntimeError) { get(:create_article) }
    assert_equal(:create_article_not_allowed.t, error.message)

    make_admin
    get(:create_article)
    assert_form_action(action: "create_article")
  end

  def test_create_article_post
    name = "Test article"
    text = "The text of a new text article."
    params = {
      article: {
        name: name,
        text: text
      }
    }
    post_requires_login(:create_article, params)
    assert_redirected_to(action: :show_article, id: Article.last.id)
  end
end
