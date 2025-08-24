# frozen_string_literal: true

require("test_helper")

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

  def test_index_with_non_default_sort
    check_index_sorting
  end

  def test_index_filtered
    article = Article.reorder(created_at: :asc).first # oldest
    query = Query.lookup(:Article, id_in_set: [article.id])
    params = { q: @controller.get_query_param(query) }
    get(:index, params:)
    assert_no_flash

    assert_select("#content a:match('href',?)", %r{/articles/\d+},
                  { count: 1 },
                  "filtered Article Index has wrong number of entries")
    assert_select(
      "a[href *= '#{article_path(article.id)}']", true,
      "filtered Article Index missing link to #{article.title} (##{article.id})"
    )
  end

  # Hm. Because the query is looked up separately from the request, there are
  # seemingly no errors to report
  def test_index_query_validation_errors
    query = Query.lookup(:Article, id_in_set: "one")
    params = { q: @controller.get_query_param(query) }
    get(:index, params:)
    # We should maybe check the behavior here because id_in_set is [nil], and
    # query.result_ids is also []. Accordingly, the index (before permalinks)
    # would show no results. But parsing the query string is allowing all
    # articles to come through, unexpectedly
    assert_flash_error(:runtime_no_matches.t(type: :article))
  end

  def test_index_links_to_create
    login(users(:article_writer).login)
    get(:index)
    assert_select("a", { text: "Create Article" },
                  "Privileged user should get link to Create Article")
  end

  def test_show
    # Prove that an actual article gets shown
    article = articles(:premier_article)
    get(:show, params: { id: article.id })
    assert_response(:success)
    assert_template(:show)
    assert(/#{article.body}/ =~ @response.body,
           "Page is missing article body")

    # Prove privileged user gets extra links
    login(users(:article_writer).login)
    get(:show, params: { id: article.id })
    assert_select("a", text: "New Article")
    assert_select("a", text: :edit_object.t(type: :article))
    assert_select(".destroy_article_link_#{article.id}", true,
                  "Page is missing Destroy button")

    # Prove that trying to show non-existent article provokes error & redirect
    get(:show, params: { id: 0 })
    assert_flash_error
    assert_response(:redirect)
  end

  # Partly duplicates title_and_tabset_helper_test `test_context_nav_dropdown`.
  # But we want to test a `destroy_button` tab too.
  # That helper calls `add_query_param` and others.
  # NOTE: we can actually call @controller.add_query_param here, fwiw.
  def test_context_nav_dropdown_helper
    article = Article.last
    links = [["Create Article", new_article_path,
              { class: "new_article_link" }],
             [:EDIT.t, edit_article_path(article.id),
              { class: "edit_article_link" }],
             [nil, article, { button: :destroy }]]

    tabs = @controller.helpers.context_nav_links(links)

    tab1 = @controller.helpers.link_to(
      "Create Article", new_article_path, { class: "new_article_link" }
    )
    tab2 = @controller.helpers.link_to(
      :EDIT.t, edit_article_path(article.id), { class: "edit_article_link" }
    )
    tab3 = @controller.helpers.destroy_button(target: article)

    assert_includes(tabs, tab1)
    assert_includes(tabs, tab2)
    assert_includes(tabs, tab3)
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
    get(:edit, params: params)
    assert_flash_text(:permission_denied.l)
    assert_redirected_to(articles_path)

    # Prove authorized user can create article
    login(users(:article_writer).login)
    make_admin
    get(:edit, params: params)
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
      post(:create, params: params)
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
      post(:create, params: params)
    end
    assert_flash_text(:article_title_required.l)
    assert_template(:new)
    assert_form_action(action: :create) # "new" form

    # Prove authorized user can create Article
    params = {
      article: { title: title, body: body }
    }
    assert_difference("Article.count", 1) do
      post(:create, params: params)
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
    post(:update, params: params)

    assert_flash_text(:permission_denied.l)
    assert_redirected_to(articles_path)

    # Prove authorized user can edit article
    login(users(:article_writer).login)
    make_admin
    post(:update, params: params)
    article.reload

    assert_flash_success
    assert_redirected_to(article_path(article.id))
    assert_equal(new_title, article.title)
    assert_equal(new_body, article.body)

    # Prove that saving without changes provokes warning
    # save it again without changes
    post(:update, params: params)
    article.reload
    assert_flash_warning
    assert_redirected_to(article_path(article.id))

    # Prove removing title provokes warning
    params[:article][:title] = ""
    post(:update, params: params)
    assert_flash_text(:article_title_required.l)
    assert_template(:edit)
    assert_form_action(action: :update) # "edit" form
  end

  def test_destroy
    article = articles(:premier_article)
    params  = { id: article.id }

    # Prove unauthorized user cannot destroy article
    login(users(:zero_user).login)
    delete(:destroy, params: params)
    assert_flash_text(:permission_denied.l)
    assert(Article.exists?(article.id))

    # Prove authorized user can destroy article
    login(article.user.login)
    make_admin
    delete(:destroy, params: params)
    assert_not(Article.exists?(article.id),
               "Failed to destroy Article #{article.id}, '#{article.title}'")
  end

  ############ test Public methods (unrouted)
end
