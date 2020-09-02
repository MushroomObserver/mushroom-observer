# frozen_string_literal: true

require("test_helper")

# Test whether actions redirected correctly
class RedirectsTest < IntegrationTestCase
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

  #######

  TERM_ID = GlossaryTerm.first.id
  GLOSSARY_USER_LOGIN = User.first.login

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
    get("/glossary/show_glossary_term/#{TERM_ID}")
    assert_equal(glossary_term_path(TERM_ID),
                 @response.request.fullpath)
  end

  def test_create_glossary_get
    login(GLOSSARY_USER_LOGIN)
    get("/glossary/create_glossary_term")
    assert_equal(new_glossary_term_path,
                 @response.request.fullpath)
  end

  def test_create_glossary_post
    login(GLOSSARY_USER_LOGIN)
    post("/glossary/create_glossary_term")
    assert_equal(new_glossary_term_path,
                 @response.request.fullpath)
  end

  def test_edit_glossary_get
    login(GLOSSARY_USER_LOGIN)
    get("/glossary/edit_glossary_term/#{TERM_ID}")
    assert_equal(edit_glossary_term_path(TERM_ID),
                 @response.request.fullpath)
  end

  def test_edit_glossary_post
    login(GLOSSARY_USER_LOGIN)
    post("/glossary/edit_glossary_term/#{TERM_ID}")
    assert_equal(edit_glossary_term_path(TERM_ID),
                 @response.request.fullpath)
  end

  def test_show_past_glossary_term
    get("/glossary/show_past_glossary_term/#{TERM_ID}?version=1")
    assert_equal(show_past_glossary_term_path(TERM_ID, version: 1),
                 @response.request.fullpath)
  end
end
