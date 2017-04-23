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
    user   = users(:rolf)
    author = user.name
    name   = "Test article"
    body   = "The body of a new test article."
    params = {
      article: {
        name:    name,
        author:  author,
        body:    body
      }
    }
    old_count = Article.count

    # Prove only admins can create articles
    login(user.login)
    error = assert_raises(RuntimeError) { post(:create_article, params) }
    assert_equal(:create_article_not_allowed.t, error.message)
    assert_equal(old_count, Article.count)

    # Prove article is created
    make_admin
    post(:create_article, params)
    assert_equal(old_count + 1, Article.count)
    article = Article.last
    assert_equal(author, article.author)
    assert_equal(body,   article.body)
    assert_equal(name,   article.name)
    assert_redirected_to(action: :show_article, id: article.id)
  end
end
