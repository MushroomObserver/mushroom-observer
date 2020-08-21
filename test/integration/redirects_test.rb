# frozen_string_literal: true

require("test_helper")

class RedirectsTest < IntegrationTestCase
  def test_controller
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

  def test_show_glossary_term
    get("/glossary/show_glossary_term/#{GlossaryTerm.first.id}")
    assert_equal(glossary_term_path(GlossaryTerm.first.id),
                 @response.request.fullpath)
  end

  def test_show_past_glossary_term
    get("/glossary/show_past_glossary_term/#{GlossaryTerm.first.id}")
    assert_equal(glossary_term_path(GlossaryTerm.first.id),
                 @response.request.fullpath)
  end
end
