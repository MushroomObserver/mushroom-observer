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
    assert_query([articles(:premier_article).id], :Article,
                 ids: [articles(:premier_article).id])
    assert_query([], :Article, ids: [])
  end
end
