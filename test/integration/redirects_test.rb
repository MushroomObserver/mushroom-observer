# frozen_string_literal: true

require("test_helper")

# Test whether actions redirected correctly
class RedirectsTest < IntegrationTestCase
  # helpers
  def assert_old_url_redirects_to_new_path(old_method, old_url, new_path)
    case old_method
    when :get
      get(old_url)
    when :delete
      delete(old_url)
    when :patch
      patch(old_url)
    when :post
      post(old_url)
    when :put
      put(old_url)
    end

    assert_equal(new_path, @response.request.fullpath)
  end

  # ============================================================================

  def test_controller_article
    get("/article")
    assert_equal(articles_path,
                 @response.request.fullpath)
  end

  def test_list_article
    get("/article/list_article")
    assert_equal(articles_path,
                 @response.request.fullpath)
  end

  def test_index_article
    get("/article/index_article/")
    assert_equal(articles_path,
                 @response.request.fullpath)
  end

  def test_show_article
    get("/article/show_article/#{Article.first.id}")
    assert_equal(article_path(Article.first.id),
                 @response.request.fullpath)
  end

  def test_create_article_get
    login("article_writer", "testpassword", true)
    get("/article/create_article")
    assert_equal(new_article_path,
                 @response.request.fullpath)
  end

  def test_create_article_post
    login("article_writer", "testpassword", true)
    post("/article/create_article")
    assert_equal(new_article_path,
                 @response.request.fullpath)
  end

  def test_edit_article_get
    login("article_writer", "testpassword", true)
    get("/article/edit_article/#{Article.first.id}")
    assert_equal(edit_article_path(Article.first.id),
                 @response.request.fullpath)
  end

  def test_edit_article_post
    login("article_writer", "testpassword", true)
    post("/article/edit_article/#{Article.first.id}")
    assert_equal(edit_article_path(Article.first.id),
                 @response.request.fullpath)
  end

  def test_destroy_article_post
    login("article_writer", "testpassword", true)
    post("/article/destroy_article/#{Article.first.id}")
    assert_equal(article_path(Article.first.id),
                 @response.request.fullpath)
  end

  def test_destroy_article_patch
    login("article_writer", "testpassword", true)
    patch("/article/destroy_article/#{Article.first.id}")
    # Rails sends patch/put to intermediate page, not the "to:" location
    assert_equal(article_url(Article.first.id),
                 @response.header["Location"])
  end

  def test_destroy_article_put
    login("article_writer", "testpassword", true)
    put("/article/destroy_article/#{Article.first.id}")
    # Rails sends patch/put to intermediate page, not the "to:" location
    assert_equal(article_url(Article.first.id),
                 @response.header["Location"])
  end

  # ----------------------------------------------------------------------------

  def test_controller_glossary
    get("/glossary")
    assert_equal(glossary_terms_path,
                 @response.request.fullpath)
  end

  def test_list_glossary_term
    get("/glossary/list_glossary_term")
    assert_equal(glossary_terms_path,
                 @response.request.fullpath)
  end

  def test_index_glossary
    get("/glossary/index_glossary_term")
    assert_equal(glossary_terms_path,
                 @response.request.fullpath)
  end

  def test_show_glossary_term
    term = glossary_terms(:conic_glossary_term)
    get("/glossary/show_glossary_term/#{term.id}")
    assert_equal(glossary_term_path(term.id),
                 @response.request.fullpath)
  end

  def test_create_glossary_get
    login(users(:rolf).login)
    get("/glossary/create_glossary_term")
    assert_equal(new_glossary_term_path,
                 @response.request.fullpath)
  end

  def test_create_glossary_post
    login(users(:rolf).login)
    post("/glossary/create_glossary_term")
    assert_equal(new_glossary_term_path,
                 @response.request.fullpath)
  end

  def test_edit_glossary_get
    login(users(:rolf).login)
    term = glossary_terms(:conic_glossary_term)
    get("/glossary/edit_glossary_term/#{term.id}")
    assert_equal(edit_glossary_term_path(term.id),
                 @response.request.fullpath)
  end

  def test_edit_glossary_post
    login(users(:rolf).login)
    term = glossary_terms(:conic_glossary_term)
    post("/glossary/edit_glossary_term/#{term.id}")
    assert_equal(edit_glossary_term_path(term.id),
                 @response.request.fullpath)
  end

  def test_show_past_glossary_term
    term = glossary_terms(:conic_glossary_term)
    get("/glossary/show_past_glossary_term/#{term.id}?version=1")
    assert_equal(show_past_glossary_term_path(term.id, version: 1),
                 @response.request.fullpath)
  end

  # ----------------------------------------------------------------------------

  # Old MO Action (method)        New "Normalized" Action (method)
  # ---------------------------   --------------------------------
  # create_herbarium (get)        new (get)
  # create_herbarium (post)       create (post)
  # delete_curator (delete)       Herbaria::Curators#destroy (delete)
  # destroy_herbarium (delete)    destroy (delete)
  # edit_herbarium (get)          edit (get)
  # edit_herbarium (post)         update (patch)
  # herbarium_search (get)        Herbaria::Searches#index (get)
  # index (get)                   Herbaria::Nonpersonals#index (get)
  # index_herbarium (get)         index (get) - lists query results
  # list_herbaria (get)           Herbaria::Alls#index (get) - all herbaria
  # merge_herbaria (get)          Herbaria::Merges#new (get)
  # next_herbarium (get)          herbaria::Nexts#show { next: "next" } (get)
  # prev_herbarium (get)          herbaria::Nexts#show { next: "prev" } (get)
  # request_to_be_curator (get)   Herbaria::CuratorRequest#new (get)
  # request_to_be_curator (post)  Herbaria::CuratorRequest#create (post)
  # show_herbarium (get)          show (get)
  # show_herbarium (post)         Herbaria::Curators#create (post)

  def test_create_herbarium_get
    login(rolf)
    assert_old_url_redirects_to_new_path(
      :get, "/herbarium/create_herbarium", new_herbarium_path
    )
  end

  def test_create_herbarium_post
    login(rolf)
    assert_old_url_redirects_to_new_path(
      :post, "/herbarium/create_herbarium", new_herbarium_path
    )
  end

  def test_delete_herbarium_curator_post
    nybg = herbaria(:nybg_herbarium)
    # make sure nobody messed up the fixtures
    assert(nybg.curator?(rolf))
    assert(nybg.curator?(roy))

    login(rolf)

    # Test the results of the redirect because
    # There is no way to test the redirect directly (unlike other actions).
    # Due to the routing scheme, Rails actually follows the redirect.
    assert_old_url_redirects_to_new_path(
      :post,
      "/herbarium/delete_curator/#{nybg.id}?user=#{roy.id}",
      herbarium_path(nybg)
    )
    assert_response(:success)
    assert_not(nybg.reload.curator?(roy))
  end

  def test_destroy_herbarium
    login(rolf)
    assert_old_url_redirects_to_new_path(
      :post,
      "/herbarium/destroy_herbarium/#{herbaria(:rolf_herbarium).id}",
      herbarium_path(herbaria(:rolf_herbarium))
    )
  end

  def test_edit_herbarium_get
    login(rolf)
    assert_old_url_redirects_to_new_path(
      :get,
      "/herbarium/edit_herbarium/#{herbaria(:rolf_herbarium).id}",
      edit_herbarium_path(herbaria(:rolf_herbarium))
    )
  end

  def test_edit_herbarium_post
    login(rolf)
    assert_old_url_redirects_to_new_path(
      :post,
      "/herbarium/edit_herbarium/#{herbaria(:rolf_herbarium).id}",
      edit_herbarium_path(herbaria(:rolf_herbarium))
    )
  end

  def test_herbarium_search
    assert_old_url_redirects_to_new_path(
      :get, "/herbarium/herbarium_search", herbaria_searches_path
    )
  end

  def test_herbarium
    assert_old_url_redirects_to_new_path(
      :get, "/herbarium", herbaria_path(flavor: :nonpersonal)
    )
  end

  def test_index_herbarium
    assert_old_url_redirects_to_new_path(
      :get, "/herbarium/index", herbaria_path
    )
  end

  def test_list_herbaria
    assert_old_url_redirects_to_new_path(
      :get, "/herbarium/list_herbaria", herbaria_path(flavor: :all)
    )
  end

  # merge_herbaria (get)          Herbaria::Merges#new (get)
  def test_merge_herbaria
    fundis = herbaria(:fundis_herbarium)
    assert_true(fundis.owns_all_records?(mary))
    marys = mary.create_personal_herbarium
    login("mary")

    get("/herbarium/merge_herbaria?this=#{fundis.id}&that=#{marys.id}")
    # fundis ends up being the destination because it is older.
    assert_equal(herbaria_path(id: fundis.id), @response.request.fullpath)
  end

  # next_herbarium (get)          herbaria::Nexts#show { next: "next" } (get)
  def test_next_herbarium
    query = Query.lookup_and_save(:Herbarium, :all)
    assert_operator(query.num_results, :>, 1,
                    "Test needs query with > 1 result")
    number1 = query.results[0]
    number2 = query.results[1]

    assert_old_url_redirects_to_new_path(
      :get,
      "/herbarium/next_herbarium/#{number1.id}",
      herbarium_path(number2, q: query.record.id.alphabetize)
    )
  end

  # prev_herbarium (get)          herbaria::Nexts#show { next: "prev" } (get)
  def test_prev_herbarium
    query = Query.lookup_and_save(:Herbarium, :all)
    assert_operator(query.num_results, :>, 1,
                    "Test needs query with > 1 result")

    number1 = query.results[0]
    number2 = query.results[1]

    assert_old_url_redirects_to_new_path(
      :get,
      "/herbarium/prev_herbarium/#{number2.id}",
      herbarium_path(number1, q: query.record.id.alphabetize)
    )
  end

  # request_to_be_curator (get)   Herbaria::CuratorRequest#new (get)
  def test_request_to_be_herbarium_curator_get
    nybg = herbaria(:nybg_herbarium)
    login("mary")

    assert_old_url_redirects_to_new_path(
      :get, "/herbarium/request_to_be_curator/#{nybg.id}",
      new_herbaria_curator_request_path(id: nybg)
    )
  end

  # request_to_be_curator (post)  Herbaria::CuratorRequest#create (post)
  def test_request_to_be_herbarium_curator_post
    nybg = herbaria(:nybg_herbarium)
    email_count = ActionMailer::Base.deliveries.count
    login("mary")
    post("/herbarium/request_to_be_curator/#{nybg.id}")

    # Rails seems to follow the redirect, instead of just redirecting
    assert_equal(herbarium_path(nybg), @response.request.fullpath)
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
  end

  # show_herbarium (get)          show (get)
  def test_show_herbarium_get
    nybg = herbaria(:nybg_herbarium)
    assert_old_url_redirects_to_new_path(
      :get, "/herbarium/show_herbarium/#{nybg.id}", herbarium_path(nybg)
    )
  end

  # show_herbarium (post)         Herbaria::Curators#create (post)
  def test_show_herbarium_post
    nybg = herbaria(:nybg_herbarium)
    assert(nybg.curators.include?(rolf))
    curator_count = nybg.curators.count
    login("rolf")
    post("/herbarium/show_herbarium?id=#{nybg.id}&add_curator=#{mary.login}")

    assert_equal(herbarium_path(nybg), @response.request.fullpath)
    assert_equal(curator_count + 1, nybg.reload.curators.count)
  end
end
