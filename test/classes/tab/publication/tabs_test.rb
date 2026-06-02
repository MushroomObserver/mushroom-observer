# frozen_string_literal: true

require("test_helper")

module Tab::Publication
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @pub = publications(:one_pub)
    end

    def test_index
      tab = Tab::Publication::Index.new

      assert_equal(:publication_index.t, tab.title)
      assert_equal(routes.publications_path, tab.path)
    end

    def test_new
      tab = Tab::Publication::New.new

      assert_equal(:add_object.t(type: :PUBLICATION), tab.title)
      assert_equal(routes.new_publication_path, tab.path)
    end

    # Regression: the i18n `[type]` interpolation in `:add_object`
    # must resolve to "Publication" — an earlier bug rendered the
    # literal `[TYPE]` when the type kwarg got dropped.
    def test_new_title_interpolates_type
      title = Tab::Publication::New.new.title

      assert_match(/Add Publication/i, title)
      assert_no_match(/\[TYPE\]/i, title)
    end
  end

  class CollectionsTest < UnitTestCase
    def setup
      @pub = publications(:one_pub)
    end

    def test_index_actions
      tabs = Tab::Publication::IndexActions.new.to_a

      assert_equal([Tab::Publication::New], tabs.map(&:class))
    end

    def test_form_new
      tabs = Tab::Publication::FormNew.new.to_a

      assert_equal([Tab::Publication::Index], tabs.map(&:class))
    end

    def test_form_edit
      tabs = Tab::Publication::FormEdit.new(publication: @pub).to_a

      assert_equal(
        [Tab::Object::Return, Tab::Publication::Index],
        tabs.map(&:class)
      )
    end
  end
end
