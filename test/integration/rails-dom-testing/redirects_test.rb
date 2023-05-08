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

  # Article to Articles------ --------------------------------------------------

  def test_controller_article
    login
    get("/article")
    assert_equal(articles_path,
                 @response.request.fullpath)
  end

  def test_list_article
    login
    get("/article/list_article")
    assert_equal(articles_path,
                 @response.request.fullpath)
  end

  def test_index_article
    login
    get("/article/index_article/")
    assert_equal(articles_path,
                 @response.request.fullpath)
  end

  def test_show_article
    get("/article/show_article/#{Article.first.id}")
    login
    assert_equal(article_path(Article.first.id),
                 @response.request.fullpath)
  end

  # Glossary to GlossaryTerms --------------------------------------------------

  def test_controller_glossary
    get("/glossary")
    login
    assert_equal(glossary_terms_path,
                 @response.request.fullpath)
  end

  def test_list_glossary_term
    get("/glossary/list_glossary_term")
    login
    assert_equal(glossary_terms_path,
                 @response.request.fullpath)
  end

  def test_index_glossary
    login
    get("/glossary/index_glossary_term")
    assert_equal(glossary_terms_path,
                 @response.request.fullpath)
  end

  def test_show_glossary_term
    term = glossary_terms(:conic_glossary_term)
    login
    get("/glossary/show_glossary_term/#{term.id}")
    assert_equal(glossary_term_path(term.id),
                 @response.request.fullpath)
  end

  # Herbarium to Herbaria ------------------------------------------------------
  #
  # legacy Herbarium action (method)  upddated Herbaria action (method)
  # --------------------------------  ---------------------------------
  # create_herbarium (get)            new (get)
  # create_herbarium (post)           create (post)
  # delete_curator (delete)           Herbaria::Curators#destroy (delete)
  # destroy_herbarium (delete)        destroy (delete)
  # edit_herbarium (get)              edit (get)
  # edit_herbarium (post)             update (patch)
  # herbarium_search (get)            index (get, pattern: present)
  # index (get)                       index (get, flavor: nonpersonal)
  # index_herbarium (get)             index (get) - query results
  # list_herbaria (get)               index (get, flavor: all) - all herbaria
  # *merge_herbaria (get)             Herbaria::Merges#create (post)
  # *next_herbarium (get)             show { flow: :next } (get))
  # *prev_herbarium (get)             show { flow: :prev } (get)
  # request_to_be_curator (get)       Herbaria::CuratorRequest#new (get)
  # request_to_be_curator (post)      Herbaria::CuratorRequest#create (post)
  # show_herbarium (get)              show (get)
  # show_herbarium (post)             Herbaria::Curators#create (post)
  # * == legacy action is not redirected
  # See https://tinyurl.com/ynapvpt7

  def test_herbarium_search
    login
    assert_old_url_redirects_to_new_path(
      :get, "/herbarium/herbarium_search", herbaria_path
    )
  end

  def test_herbarium
    login
    assert_old_url_redirects_to_new_path(
      :get, "/herbarium", herbaria_path(flavor: :nonpersonal)
    )
  end

  def test_index_herbarium
    login
    assert_old_url_redirects_to_new_path(
      :get, "/herbarium/index", herbaria_path
    )
  end

  def test_list_herbaria
    login
    assert_old_url_redirects_to_new_path(
      :get, "/herbarium/list_herbaria", herbaria_path(flavor: :all)
    )
  end

  def test_show_herbarium_get
    nybg = herbaria(:nybg_herbarium)
    login
    assert_old_url_redirects_to_new_path(
      :get, "/herbarium/show_herbarium/#{nybg.id}", herbarium_path(nybg)
    )
  end

  # Observer/lookup_... to Lookups  ---------------------------------

  # The only legacy lookup that was ok'd for use by external sites
  def test_lookup_name_get
    name = names(:fungi)
    login
    assert_old_url_redirects_to_new_path(
      :get, "/observer/lookup_name/#{name.id}", name_path(name.id)
    )
  end

  # Name ---------------------------------

  def test_name_search_get
    name = names(:tremella_mesenterica)

    login
    get("/name/name_search?pattern=#{name.text_name}")

    assert_equal(name_path(name.id), @response.request.path)
  end

  # SpecisList/show  ---------------------------------
  def test_show_species_list
    spl = species_lists(:first_species_list)
    login
    assert_old_url_redirects_to_new_path(
      :get, "/species_list/show_species_list//#{spl.id}", species_list_path(spl)
    )
  end
end
