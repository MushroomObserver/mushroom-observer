require "test_helper"

# Controller tests for news articles
class ArticleControllerTest < FunctionalTestCase
  def test_create_article_get
    # Prove unathorized user cannot see create_article form
    login(users(:zero_user).login)
    get(:create_article)
    assert_flash_text(:permission_denied.l)
    assert_redirected_to(action: :index)

    # Prove authorized user can go to create_article form
    login(users(:article_permission_user).login)
    make_admin
    get(:create_article)
    assert_form_action(action: "create_article")
  end

  def test_create_article_post
    user   = users(:article_permission_user)
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

    # Prove unauthorized user cannot create article
    login(users(:zero_user).login)
    post(:create_article, params)
    assert_flash_text(:permission_denied.l)
    assert_equal(old_count, Article.count)
    assert_redirected_to(action: :index)

    # Prove authorized user can create article
    login(user.login)
    make_admin
    post(:create_article, params)
    assert_equal(old_count + 1, Article.count)
    article = Article.last
    assert_equal(body, article.body)
    assert_equal(name, article.name)
    assert_redirected_to(action: :show_article, id: article.id)
  end

  def test_edit_article_get
    # Prove unauthorized user cannot see edit form
    article = articles(:premier_article)
    params = { id: article.id }

    login(users(:zero_user).login)
    get(:edit_article, params)
    assert_flash_text(:permission_denied.l)
    assert_redirected_to(action: :index)

    # Prove authorized user can create article
    login(article.user.login)
    make_admin
    get(:edit_article, params)
    assert_form_action(action: "edit_article")
  end

  def test_index
    get(:index)
    assert_template(:index)
  end

  def test_show_article
    get(:show_article, id: articles(:premier_article).id)
    assert_template(:show_article)
  end

=begin
  def test_edit_article_logged_in
    login
    get_with_dump(:edit_article, id: conic.id)
    assert_template(:edit_article)
  end

  def test_edit_article_post
    old_count = GlossaryTerm::Version.count
    make_admin
    params = create_article_params
    params[:id] = conic.id

    post(:edit_article, params)
    conic.reload

    assert_equal(params[:article][:name], conic.name)
    assert_equal(params[:article][:description], conic.description)
    assert_equal(old_count + 1, GlossaryTerm::Version.count)
    assert_response(:redirect)
  end
=end
end
