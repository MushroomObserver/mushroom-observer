# frozen_string_literal: true

require("test_helper")

class ArticleTest < UnitTestCase
  def test_can_edit
    article = articles(:premier_article)
    assert(article.can_edit?(users(:article_writer)))
    assert_not(article.can_edit?(users(:zero_user)))
  end

  def test_destroy_orphans_log
    article = articles(:premier_article)
    log = article.rss_log
    assert_not_nil(log)
    article.destroy!
    assert_nil(log.reload.target_id)
  end
end
