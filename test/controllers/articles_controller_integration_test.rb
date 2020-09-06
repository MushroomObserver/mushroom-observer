# frozen_string_literal: true

require("test_helper")

# Controller tests for news articles
class ArticlesControllerIntegrationTest < FunctionalIntegrationTestCase
  ############ test Actions that Display data (index, show, etc.)

  def test_index
    # get(:index)
    get(articles_path)
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

    # params = @controller.query_params(query) # controller method not available
    # params[:q] = get_query_param(query)
    # get(:index, params: params)
    get(articles_path(q: get_query_param(query)))
    assert_select("a:match('href',?)", %r{/articles/\d+}, { count: 1 },
                  "filtered Article Index has wrong number of entries")
    assert_select(
      "a[href *= '#{article_path(article.id)}']", true,
      "filtered Article Index missing link to #{article.title} (##{article.id})"
    )
  end

  def test_index_links_to_create
    login(users(:article_writer).login)
    # get(:index)
    get(articles_path)
    assert_select("a", { text: :create_article_title.l },
                  "Privileged user should get link to Create Article")
  end

  def test_show
    # Prove that an actual article gets shown
    article = articles(:premier_article)
    # get(:show, params: { id: article.id })
    get(article_path(id: article.id))
    # assert_response(:success)
    # assert_template(:show)
    assert_equal(article_path(id: article.id), path)
    assert(/#{article.body}/ =~ @response.body,
           "Page is missing article body")

    # Prove privileged user gets extra links
    login(users(:article_writer).login)
    # get(:show, params: { id: article.id })
    get(article_path(id: article.id))
    assert_select("a", text: :create_article_title.l)
    assert_select("a", text: :EDIT.l)
    assert_select("a", text: :DESTROY.l)

    # Prove that trying to show non-existent article provokes error & redirect
    # get(:show, params: { id: 0 })
    get(article_path(id: 0))
    assert_flash_error
    # assert_response(:redirect) # Probably not. get always follow_redirects!
    # where should it get redirected to? Guessing the index - AN
    assert_equal(articles_path, path)
  end

  ############ test Actions that Display forms -- (new, edit, etc.)

  def test_new
    # Prove unathorized user cannot see create_article form
    login(users(:zero_user).login)
    # get(:new)
    get(new_article_path)
    assert_flash_text(:permission_denied.l)
    # assert_redirected_to(articles_path)
    assert_equal(articles_path, path)

    # Prove authorized user can go to create_article form
    login(users(:article_writer).login)
    make_admin
    # get(:new)
    get(new_article_path)
    assert_form_action(action: :create) # "new" form posts to :create action

    # Prove that if News Articles project doesn't exist, there's no error.
    Project.destroy(Article.news_articles_project.id)
    # get(:new)
    get(new_article_path)
    assert_flash_text(:permission_denied.l)
    # assert_redirected_to(articles_path)
    assert_equal(articles_path, path)
  end

  def test_edit
    # Prove unauthorized user cannot see edit form
    article = articles(:premier_article)
    params = { id: article.id }

    login(users(:zero_user).login)
    # get(:edit, params: params)
    get(edit_article_path(params))
    assert_flash_text(:permission_denied.l)
    # assert_redirected_to(articles_path)
    assert_equal(articles_path, path)

    # Prove authorized user can create article
    login(users(:article_writer).login)
    make_admin
    # get(:edit, params: params)
    get(edit_article_path(params))
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
      # post(:create, params: params)
      post(articles_path, params: params)
    end
    assert_flash_text(:permission_denied.l)
    # assert_redirected_to(articles_path)
    assert_equal(articles_path, path)

    # Prove authorized user cannot create title-less Article
    login(user.login)
    make_admin
    params = {
      article: { title: "", body: body }
    }
    assert_no_difference("Article.count") do
      # post(:create, params: params)
      post(articles_path, params: params)
    end
    assert_flash_text(:article_title_required.l)
    # assert_template(:new)
    # NOTE: This does not seemingly go to the new article form.
    # Path is now articles_path, because we posted. However, form action works.
    assert_equal(articles_path, path)
    assert_form_action(action: :create) # "new" form

    # Prove authorized user can create Article
    params = {
      article: { title: title, body: body }
    }
    assert_difference("Article.count", 1) do
      # post(:create, params: params)
      post(articles_path, params: params)
    end
    article = Article.last
    assert_equal(body, article.body)
    assert_equal(title, article.title)
    # assert_redirected_to(article_path(article.id))
    # follow_redirect!
    assert_equal(article_path(article.id), path)
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
    # post(:update, params: params)
    patch(article_path(params))
    assert_flash_text(:permission_denied.l)
    assert_redirected_to(articles_path)
    # assert_equal(articles_path, path)

    # Prove authorized user can edit article
    login(users(:article_writer).login)
    make_admin
    # post(:update, params: params)
    patch(article_path(params))
    article.reload

    assert_flash_success
    # assert_redirected_to(article_path(article.id))
    assert_equal(article_path(article.id), path)
    assert_equal(new_title, article.title)
    assert_equal(new_body, article.body)

    # Prove that saving without changes provokes warning
    # save it again without changes
    # post(:update, params: params)
    patch(article_path(params))
    article.reload
    assert_flash_warning
    # assert_redirected_to(article_path(article.id))
    assert_equal(article_path(article.id), path)

    # Prove removing title provokes warning
    params[:article][:title] = ""
    # post(:update, params: params)
    patch(article_path(params))
    # NOTE: The flash text is perplexing! It seems to give a Both/And!
    # <p>Successfully updated article #788338338.</p><p>No changes made.</p><p>Title Required</p>
    assert_flash_text(:article_title_required.l)
    # assert_template(:edit)
    assert_equal(edit_article_path(params), path)
    assert_form_action(action: :update) # "edit" form
  end

  def test_destroy
    article = articles(:premier_article)
    params  = { id: article.id }

    # Prove unauthorized user cannot destroy article
    login(users(:zero_user).login)
    # delete(:destroy, params: params)
    delete(article_path(params))
    assert_flash_text(:permission_denied.l)
    assert(Article.exists?(article.id))

    # Prove authorized user can destroy article
    login(article.user.login)
    make_admin
    # delete(:destroy, params: params)
    delete(article_path(params))
    assert_not(Article.exists?(article.id),
               "Failed to destroy Article #{article.id}, '#{article.title}'")
  end

  ############ test Public methods (unrouted)
end
