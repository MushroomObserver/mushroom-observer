# frozen_string_literal: true

require("test_helper")

# Simple smoke tests for article form submission
class ArticlesIntegrationTest < CapybaraIntegrationTestCase
  def test_create_article
    # Login as a member of the News Articles project (the only thing
    # gating article create/edit/destroy after issue #4145).
    login(users(:article_writer))

    # Visit the new article page
    visit(new_article_path)
    assert_selector("body.articles__new")

    # Fill in the form with valid data
    fill_in("article_title", with: "Test Article")
    fill_in("article_body", with: "This is a test article body.")

    # Submit the form
    within("form[action='/articles']") do
      click_commit
    end

    # Verify successful creation
    assert_selector("body.articles__show")

    # Verify database effect
    article = Article.find_by(title: "Test Article")
    assert_not_nil(article, "Cannot find Article")
    assert_equal("Test Article", article.title)
    assert_equal("This is a test article body.", article.body)
  end

  def test_edit_article
    # Login as a member of the News Articles project.
    login(users(:article_writer))
    article = articles(:premier_article)

    # Visit the edit article page
    visit(edit_article_path(article))
    assert_selector("body.articles__edit")

    # Update the form with valid data
    fill_in("article_title", with: "Updated Article Title")
    fill_in("article_body", with: "Updated article body.")

    # Submit the form
    within("form[action='#{article_path(article)}']") do
      click_commit
    end

    # Verify successful update
    assert_selector("body.articles__show")

    # Verify database effect
    article.reload
    assert_equal("Updated Article Title", article.title)
    assert_equal("Updated article body.", article.body)
  end
end
