# frozen_string_literal: true

require("test_helper")
require("query_extensions")

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

  def test_article_in_set
    assert_query([articles(:premier_article).id],
                 :Article, id_in_set: [articles(:premier_article).id])
    assert_query([], :Article, id_in_set: [])
  end

  def test_article_title_has
    assert_query([articles(:premier_article)],
                 :Article, title_has: "premier_article")
    assert_query(Article.title_has("premier_article"),
                 :Article, title_has: "premier_article")
  end

  def test_article_body_has
    assert_query([articles(:second_article)],
                 :Article, body_has: "second_article")
    assert_query(Article.body_has("second_article"),
                 :Article, body_has: "second_article")
  end
end
