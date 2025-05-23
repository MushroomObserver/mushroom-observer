# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Articles class to be included in QueryTest
class Query::ArticlesTest < UnitTestCase
  include QueryExtensions

  def test_article_all
    expects = [articles(:premier_article), articles(:second_article)]
    scope = Article.order_by_default
    assert_query_scope(expects, scope, :Article)
  end

  def test_article_by_rss_log
    assert_query(Article.order_by(:rss_log), :Article, order_by: :rss_log)
  end

  def test_article_id_in_set
    art = articles(:premier_article)
    expects = [art.id]
    scope = Article.id_in_set(art.id)
    assert_query_scope(expects, scope, :Article, id_in_set: [art.id])
    assert_query([], :Article, id_in_set: [])
  end

  def test_article_title_has
    expects = [articles(:premier_article)]
    scope = Article.title_has("premier_article").order_by_default
    assert_query_scope(expects, scope, :Article, title_has: "premier_article")
  end

  def test_article_body_has
    expects = [articles(:second_article)]
    scope = Article.body_has("second_article").order_by_default
    assert_query_scope(expects, scope, :Article, body_has: "second_article")
  end

  def test_article_by_users
    expects = [articles(:premier_article)]
    scope = Article.by_users(rolf).order_by_default
    assert_query_scope(expects, scope, :Article, by_users: rolf.id)
  end
end
