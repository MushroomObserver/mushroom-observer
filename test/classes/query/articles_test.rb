# frozen_string_literal: true

require "test_helper"
require "query_extensions"

# tests of Query::Articles class to be included in QueryTest
class Query::ArticlesTest < UnitTestCase
  include QueryExtensions

  def test_article_all
    expects = Article.index_order
    assert_query(expects, :Article)
  end

  def test_article_by_rss_log
    assert_query(Article.order_by_rss_log, :Article, by: :rss_log)
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
    scope = Article.title_has("premier_article").index_order
    assert_query_scope(expects, scope, :Article, title_has: "premier_article")
  end

  def test_article_body_has
    expects = [articles(:second_article)]
    scope = Article.body_has("second_article").index_order
    assert_query_scope(expects, scope, :Article, body_has: "second_article")
  end

  def test_article_by_users
    expects = [articles(:premier_article)]
    scope = Article.by_users(rolf).index_order
    assert_query_scope(expects, scope, :Article, by_users: rolf.id)
  end
end
