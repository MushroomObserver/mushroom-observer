# frozen_string_literal: true

require("test_helper")

module Tab::RssLog
  class TabsTest < UnitTestCase
    def setup
      @user = users(:rolf)
    end

    def test_make_default
      tab = Tab::RssLog::MakeDefault.new(path: "/rss_logs?make_default=1")

      assert_equal(:rss_make_default.t, tab.title)
      assert_equal("/rss_logs?make_default=1", tab.path)
    end

    # IndexActions covers 3 conditional branches: make_default already
    # in URL → empty; user default matches current types → empty;
    # current types differ → show MakeDefault tab.
    def test_index_actions_make_default_already_set
      tabs = Tab::RssLog::IndexActions.new(
        user: @user, types: %w[observation],
        make_default_param: "1", make_default_path: "/x"
      ).to_a

      assert_empty(tabs)
    end

    def test_index_actions_user_default_matches
      @user.default_rss_type = "observation"
      tabs = Tab::RssLog::IndexActions.new(
        user: @user, types: ["observation"],
        make_default_param: nil, make_default_path: "/x"
      ).to_a

      assert_empty(tabs)
    end

    def test_index_actions_user_default_differs
      @user.default_rss_type = "observation"
      tabs = Tab::RssLog::IndexActions.new(
        user: @user, types: ["name"],
        make_default_param: nil, make_default_path: "/x"
      ).to_a

      assert_equal([Tab::RssLog::MakeDefault], tabs.map(&:class))
    end
  end
end
