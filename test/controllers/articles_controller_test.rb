require "test_helper"

# Controller tests for news articles
class ArticlesControllerTest < FunctionalTestCase
  def test_create_article_get
    # Prove unathorized user cannot see new form
    login(users(:zero_user).login)
    get(:new)
    assert_flash_text(:permission_denied.l)
    assert_redirected_to(action: :index_article)

    # Prove authorized user can go to new form
    login(users(:article_writer).login)
    make_admin
    get(:new)
    assert_form_action(action: :new)

    # Prove that if News Articles project doesn't exist, there's no error.
    Project.destroy(Article.news_articles_project.id)
    get(:new)
    assert_flash_text(:permission_denied.l)
    assert_redirected_to(action: :index_article)
  end

  def test_create_article_post
    user   = users(:article_writer)
    title  = "Test article"
    body   = "The body of a new test article."
    params = {
      article: { title: title, body: body }
    }
    old_count = Article.count

    # Prove unauthorized user cannot create Article
    login(users(:zero_user).login)
    post(:new, params)
    assert_flash_text(:permission_denied.l)
    assert_equal(old_count, Article.count)
    assert_redirected_to(action: :index_article)

    # Prove authorized user cannot create title-less Article
    login(user.login)
    make_admin
    params = {
      article: { title: "", body: body }
    }
    post(:new, params)
    assert_equal(old_count, Article.count)
    assert_flash_text(:article_title_required.l)
    assert_template(:new)

    # Prove authorized user can create Article
    params = {
      article: { title: title, body: body }
    }
    post(:new, params)
    assert_equal(old_count + 1, Article.count)
    article = Article.last
    assert_equal(body, article.body)
    assert_equal(title, article.title)
    assert_redirected_to(action: :show, id: article.id)
    assert_not_nil(article.rss_log, "Failed to create rss_log entry")
  end

  def test_edit_article_get
    # Prove unauthorized user cannot see edit form
    article = articles(:premier_article)
    params = { id: article.id }

    login(users(:zero_user).login)
    get(:edit, params)
    assert_flash_text(:permission_denied.l)
    assert_redirected_to(action: :index_article)

    # Prove authorized user can create article
    login(users(:article_writer).login)
    make_admin
    get(:edit, params)
    assert_form_action(action: :edit)
  end

  def test_edit_article_post
    # Prove unauthorized user cannot edit article
    article = articles(:premier_article)
    new_title = "Edited Article Title"
    new_body = "Edited body"
    params = {
      id: article.id,
      article: { title: new_title, body: new_body }
    }
    login(users(:zero_user).login)
    post(:edit, params)

    assert_flash_text(:permission_denied.l)
    assert_redirected_to(action: :index_article)

    # Prove authorized user can edit article
    login(users(:article_writer).login)
    make_admin
    post(:edit, params)
    article.reload

    assert_flash_success
    assert_redirected_to(action: :show, id: article.id)
    assert_equal(new_title, article.title)
    assert_equal(new_body, article.body)

    # Prove that saving without changes provokes warning
    # save it again without changes
    post(:edit, params)
    article.reload
    assert_flash_warning
    assert_redirected_to(action: :show, id: article.id)

    # Prove removing title provokes warning
    params[:article][:title] = ""
    post(:edit, params)
    assert_flash_text(:article_title_required.l)
    assert_template(:edit)
  end

  def test_destroy_article
    article = articles(:premier_article)
    params  = { id: article.id }

    # Prove unauthorized user cannot destroy article
    login(users(:zero_user).login)
    get(:destroy, params)
    assert_flash_text(:permission_denied.l)
    assert(Article.exists?(article.id))

    # Prove authorized user can destroy article
    login(article.user.login)
    make_admin
    get(:destroy, params)
    assert_not(Article.exists?(article.id),
               "Failed to destroy Article #{article.id}, '#{article.title}'")
  end

  # possibly rename this method to test_index_article (index based on query)
  def test_index
    # Prove any user can see article index
    get(:index_article)
    assert(:success)

    # Prove privileged user get link to create an article
    login(users(:article_writer).login)
    get(:index_article)
    assert_select("a", text: :create_article_title.l)
  end

  # Note that list_articles is now an alias for index, the unfiltered list
  def test_list_articles
    get(:index)
    assert(:success)
  end

  def test_show_article
    # Prove that an actual article gets shown
    get(:show, id: articles(:premier_article).id)
    assert_response(:success)
    assert_template(:show)

    # Prove privileged user gets extra links
    login(users(:article_writer).login)
    get(:show, id: articles(:premier_article).id)
    assert_select("a", text: :create_article_title.l)
    assert_select("a", text: :EDIT.l)
    assert_select("a", text: :DESTROY.l)

    # Prove that trying to show non-existent article provokes error & redirect
    get(:show, id: -1)
    assert_flash_error
    assert_response(:redirect)
  end
end
