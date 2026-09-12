# frozen_string_literal: true

require("test_helper")

class Title::ArticleTest < UnitTestCase
  def test_page_title
    article = articles(:premier_article)

    assert_equal(article.display_title.t, Title.for(article).page_title)
  end

  def test_document_title
    article = articles(:premier_article)

    assert_equal(article.title, Title.for(article).document_title)
  end
end
