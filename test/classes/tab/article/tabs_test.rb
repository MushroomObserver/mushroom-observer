# frozen_string_literal: true

require("test_helper")

module Tab::Article
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @article = articles(:premier_article)
    end

    def test_index
      tab = Tab::Article::Index.new

      assert_equal(:index_article.t, tab.title)
      assert_equal(routes.articles_path, tab.path)
      assert_equal(Article, tab.model)
    end

    def test_new
      tab = Tab::Article::New.new

      assert_equal(:create_object.t(type: :article), tab.title)
      assert_equal(routes.new_article_path, tab.path)
      assert_equal(Article, tab.model)
    end
  end

  class CollectionsTest < UnitTestCase
    def setup
      @article = articles(:premier_article)
      @writer = users(:article_writer)
      @non_writer = users(:mary)
    end

    def test_index_actions_when_can_edit
      tabs = Tab::Article::IndexActions.new(user: @writer).to_a

      assert_equal([Tab::Article::New], tabs.map(&:class))
    end

    def test_index_actions_when_cannot_edit
      tabs = Tab::Article::IndexActions.new(user: @non_writer).to_a

      assert_empty(tabs)
    end

    def test_form_new
      tabs = Tab::Article::FormNew.new.to_a

      assert_equal([Tab::Article::Index], tabs.map(&:class))
    end

    def test_form_edit
      tabs = Tab::Article::FormEdit.new(article: @article).to_a

      assert_equal(
        [Tab::Object::Return, Tab::Article::Index],
        tabs.map(&:class)
      )
    end
  end
end
