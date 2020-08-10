# frozen_string_literal: true

require("test_helper")

class RedirectsTest < IntegrationTestCase
  def test_list_article
    get("/article/list_article")
    assert_equal("/articles", @response.request.fullpath)
  end

  def test_index_article
    get("/article/index_article/")
    assert_equal("/articles", @response.request.fullpath)
  end

  def test_show_article
    get("/article/show_article/#{Article.first.id}")
    assert_equal("/articles/#{Article.first.id}", @response.request.fullpath)
  end

  def test_create_article_get
    login!("article_writer", "testpassword", true)
    get("/article/create_article")
    assert_equal("/articles/new", @response.request.fullpath)
  end

  def test_create_article_post
    login!("article_writer", "testpassword", true)
    post("/article/create_article")
    assert_equal("/articles/new", @response.request.fullpath)
  end

  def test_edit_article_get
    login!("article_writer", "testpassword", true)
    get("/article/edit_article/#{Article.first.id}")
    assert_equal("/articles/#{Article.first.id}/edit",
                 @response.request.fullpath)
  end

  def test_edit_article_post
    login!("article_writer", "testpassword", true)
    post("/article/edit_article/#{Article.first.id}")
    assert_equal("/articles/#{Article.first.id}/edit",
                 @response.request.fullpath)
  end

  def test_destroy_article_post
    login!("article_writer", "testpassword", true)
    post("/article/destroy_article/#{Article.first.id}")
    assert_equal("/articles/#{Article.first.id}",
                 @response.request.fullpath)
  end

=begin

  def test_edit_article_get
    get("/article/show_article/#{Article.first.id}")
    assert_equal(@response.request.fullpath, "/articles/#{Article.first.id}")
  end

  def test_edit_article_post
    get("/article/show_article/#{Article.first.id}")
    assert_equal(@response.request.fullpath, "/articles/#{Article.first.id}")
  end

  def test_delete_article
    get("/article/show_article/#{Article.first.id}")
    assert_equal(@response.request.fullpath, "/articles/#{Article.first.id}")
  end
=end
end
