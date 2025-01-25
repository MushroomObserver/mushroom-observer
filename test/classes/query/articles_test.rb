# frozen_string_literal: true

require("test_helper")

# tests of Query::Articles class to be included in QueryTest
module Query::ArticlesTest
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
