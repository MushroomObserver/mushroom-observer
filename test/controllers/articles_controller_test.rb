# frozen_string_literal: true

require "test_helper"

# Controller tests for news articles
class ArticlesControllerTest < FunctionalTestCase
  ############ test Actions that Display data (index, show, etc.)

  def test_index
    get(:index)
    assert(:success, "Any user should be able to see article index")
    Article.find_each do |article|
      assert_select(
        "a[href *= '#{article_path(article.id)}']", true,
        "full Article Index missing link to #{article.title} (##{article.id})"
      )
    end
  end

  def test_index_filtered
    article = Article.first
    query = Query.lookup(:Article, :in_set, ids: [article.id])
    params = @controller.query_params(query)
    get(:index, params: params)
    assert_select("a:match('href',?)", %r{/articles/\d+}, { count: 1 },
                  "filtered Article Index has wrong number of entries")
    assert_select(
      "a[href *= '#{article_path(article.id)}']", true,
      "filtered Article Index missing link to #{article.title} (##{article.id})"
    )
  end

  def test_index_links_to_create
    login(users(:article_writer).login)
    get(:index)
    assert_select("a", { text: :create_article_title.l },
                  "Privileged user should get link to Create Article")
  end

  def test_show
    # Prove that an actual article gets shown
    article = articles(:premier_article)
    get(:show, id: article.id)
    assert_response(:success)
    assert_template(:show)
    assert(/#{article.body}/ =~ @response.body,
           "Page is missing article body")

    # Prove privileged user gets extra links
    login(users(:article_writer).login)
    get(:show, id: article.id)
    assert_select("a", text: :create_article_title.l)
    assert_select("a", text: :EDIT.l)
    assert_select("a", text: :DESTROY.l)

    # Prove that trying to show non-existent article provokes error & redirect
    get(:show, id: -1)
    assert_flash_error
    assert_response(:redirect)
  end

  ############ test Actions that Display forms -- (new, edit, etc.)

  def test_new
    # Prove unathorized user cannot see create_article form
    login(users(:zero_user).login)
    get(:new)
    assert_flash_text(:permission_denied.l)
    assert_redirected_to(articles_path)

    # Prove authorized user can go to create_article form
    login(users(:article_writer).login)
    make_admin
    get(:new)
    assert_form_action(action: :create) # "new" form posts to :create action

    # Prove that if News Articles project doesn't exist, there's no error.
    Project.destroy(Article.news_articles_project.id)
    get(:new)
    assert_flash_text(:permission_denied.l)
    assert_redirected_to(articles_path)
  end

  def test_edit
    # Prove unauthorized user cannot see edit form
    article = articles(:premier_article)
    params = { id: article.id }

    login(users(:zero_user).login)
    get(:edit, params)
    assert_flash_text(:permission_denied.l)
    assert_redirected_to(articles_path)

    # Prove authorized user can create article
    login(users(:article_writer).login)
    make_admin
    get(:edit, params)
    assert_form_action(action: :update) # "edit" form posts to :update action
  end

  ############ test Actions to Modify data: (create, update, destroy, etc.)

  def test_create
    user   = users(:article_writer)
    title  = "Test article"
    body   = "The body of a new test article."
    params = {
      article: { title: title, body: body }
    }

    # Prove unauthorized user cannot create Article
    login(users(:zero_user).login)
    assert_no_difference("Article.count") do
      post(:create, params)
    end
    assert_flash_text(:permission_denied.l)
    assert_redirected_to(articles_path)

    # Prove authorized user cannot create title-less Article
    login(user.login)
    make_admin
    params = {
      article: { title: "", body: body }
    }
    assert_no_difference("Article.count") do
      post(:create, params)
    end
    assert_flash_text(:article_title_required.l)
    assert_template(:new)
    assert_form_action(action: :create) # "new" form

    # Prove authorized user can create Article
    params = {
      article: { title: title, body: body }
    }
    assert_difference("Article.count", 1) do
      post(:create, params)
    end
    article = Article.last
    assert_equal(body, article.body)
    assert_equal(title, article.title)
    assert_redirected_to(article_path(article.id))
    assert_not_nil(article.rss_log, "Failed to create rss_log entry")
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
    assert_redirected_to(articles_path)

    # Prove authorized user can edit article
    login(users(:article_writer).login)
    make_admin
    post(:update, params)
    article.reload

    assert_flash_success
    assert_redirected_to(article_path(article.id))
    assert_equal(new_title, article.title)
    assert_equal(new_body, article.body)

    # Prove that saving without changes provokes warning
    # save it again without changes
    post(:update, params)
    article.reload
    assert_flash_warning
    assert_redirected_to(article_path(article.id))

    # Prove removing title provokes warning
    params[:article][:title] = ""
    post(:update, params)
    assert_flash_text(:article_title_required.l)
    assert_template(:edit)
    assert_form_action(action: :update) # "edit" form
  end

  def test_destroy
    article = articles(:premier_article)
    params  = { id: article.id }

    # Prove unauthorized user cannot destroy article
    login(users(:zero_user).login)
    delete(:destroy, params)
    assert_flash_text(:permission_denied.l)
    assert(Article.exists?(article.id))

    # Prove authorized user can destroy article
    login(article.user.login)
    make_admin
    delete(:destroy, params)
    assert_not(Article.exists?(article.id),
               "Failed to destroy Article #{article.id}, '#{article.title}'")
  end

  ############ test Public methods (unrouted)
end
