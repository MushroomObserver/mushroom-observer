# frozen_string_literal: true

require "test_helper"

# Controller tests for news articles
class ArticlesControllerTest < FunctionalTestCase
  # Prove anyone can see (complete) article index
  def test_index
    get(:index)
    assert(:success)
    # Prove index (or redirect) includes link to first article
    assert_select("a[href *= '#{Article.first.id}']", true,
                  "Page is missing a link to an article")
  end

  def test_index_article
    # Prove any user can see article index (based on current query)
    get(:index_article)
    assert(:success)
  end

  def test_index_article_ui
    login(users(:article_writer).login)
    get(:index_article)
    assert_select(
      "a#create_link[href='#{new_article_path}']", true,
      "article_writers group member should get link to create article")

    login(users(:zero_user).login)
    get(:index_article)
    assert_select(
      "a#create_link[href='#{new_article_path}']", false,
      "article_writers group non-member should not get link to create article")
  end

  def test_show
    # Prove that an actual article gets shown
    get(:show, id: articles(:premier_article).id)
    assert_response(:success)
    assert_template(:show)

    # Prove that trying to show non-existent article provokes error & redirect
    get(:show, id: -1)
    assert_flash_error
    assert_response(:redirect)
  end

  def test_show_privileged_user_links
    # Prove privileged user gets extra links
    login(users(:article_writer).login)
    get(:show, id: articles(:premier_article).id)

    assert_select("a#create_link[href='#{new_article_path}']", true,
                  "Page is missing a link to :create")
    assert_select("a#edit_link[href='#{edit_article_path}']", true,
                  "Page is missing a link to :edit")
    assert_select("a#destroy_link[href='#{destroy_article_path}']", true,
                  "Page is missing a link to :destroy")
   end

  def test_new
    # Prove unathorized user cannot see new form
    login(users(:zero_user).login)
    get(:new)
    assert_flash_text(:permission_denied.l)
    assert_redirected_to(action: :index_article)

    # Prove authorized user succeeds and gets to the right form
    login(users(:article_writer).login)
    make_admin
    get(:new)
    assert(:success)
    assert_form_action(action: :create) # "new" form posts to :create

    # Prove that if News Articles project doesn't exist, there's no error.
    Project.destroy(Article.news_articles_project.id)
    get(:new)
    assert_flash_text(:permission_denied.l)
    assert_redirected_to(action: :index_article)
  end

  def test_create
    user   = users(:article_writer)
    title  = "Test article"
    body   = "The body of a new test article."
    params = {
      article: { title: title, body: body }
    }
    old_count = Article.count

    # Prove unauthorized user cannot create Article
    login(users(:zero_user).login)
    post(:create, params)
    assert_flash_text(:permission_denied.l)
    assert_equal(old_count, Article.count)
    assert_redirected_to(action: :index_article)

    # Prove authorized user cannot create title-less Article
    login(user.login)
    make_admin
    params = {
      article: { title: "", body: body }
    }
    post(:create, params)
    assert_equal(old_count, Article.count)
    assert_flash_text(:article_title_required.l)
    assert_template(:new)

    # Prove authorized user can create Article
    params = {
      article: { title: title, body: body }
    }
    post(:create, params)
    assert_equal(old_count + 1, Article.count)
    article = Article.last
    assert_equal(body, article.body)
    assert_equal(title, article.title)
    assert_redirected_to(action: :show, id: article.id)
    assert_not_nil(article.rss_log, "Failed to create rss_log entry")
  end

  def test_edit
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
    assert_form_action(action: :update) # "edit" form posts to :create action
  end

  def test_update
    # Prove unauthorized user cannot edit article
    article = articles(:premier_article)
    new_title = "Edited Article Title"
    new_body = "Edited body"
    params = {
      id: article.id,
      article: { title: new_title, body: new_body }
    }
    login(users(:zero_user).login)
    post(:update, params)

    assert_flash_text(:permission_denied.l)
    assert_redirected_to(action: :index_article)

    # Prove authorized user can edit article
    login(users(:article_writer).login)
    make_admin
    post(:update, params)
    article.reload

    assert_flash_success
    assert_redirected_to(action: :show, id: article.id)
    assert_equal(new_title, article.title)
    assert_equal(new_body, article.body)

    # Prove that saving without changes provokes warning
    # save it again without changes
    post(:update, params)
    article.reload
    assert_flash_warning
    assert_redirected_to(action: :show, id: article.id)

    # Prove removing title provokes warning
    params[:article][:title] = ""
    post(:update, params)
    assert_flash_text(:article_title_required.l)
    assert_template(:edit)
  end

  def test_destroy
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
end
