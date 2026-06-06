# frozen_string_literal: true

require("test_helper")

# test the application-wide helpers
class ApplicationHelperTest < ActionView::TestCase
  # Required stubs for helpers that delegate to controller context
  def in_admin_mode? = false

  # define_singleton_method avoids `def obj.method` syntax, which the
  # duplicate-method scanner in LocalizationFilesTest flags as a duplicate
  # when the same pattern appears in more than one test.
  def browser
    Object.new.tap { |b| b.define_singleton_method(:bot?) { false } }
  end

  def test_add_args_to_url_two_args
    assert_equal("/abcdef?foo=bar&this=that",
                 add_args_to_url("/abcdef", foo: "bar", this: "that"))
  end

  def test_add_args_to_url_arg_replaces_url_parameter
    assert_equal("/abcdef?foo=bar&this=that",
                 add_args_to_url("/abcdef?foo=wrong", foo: "bar", this: "that"))
  end

  def test_add_args_to_url_append_args_to_url
    result = add_args_to_url("/abcdef?foo=wrong&a=2", foo: '"bar"',
                                                      this: "that")
    assert(result.start_with?("/abcdef?"), "Should start with path")
    assert_includes(result, "a=2", "Should preserve existing param")
    assert_includes(result, "foo=%22bar%22", "Should replace foo param")
    assert_includes(result, "this=that", "Should add new param")
  end

  def test_add_args_to_url_ending_with_id
    assert_equal("/blah/blah/5?arg=new",
                 add_args_to_url("/blah/blah/5", arg: "new"))
  end

  def test_add_args_to_url_id_arg_replaces_id_in_url
    assert_equal("/blah/blah/4?arg=new",
                 add_args_to_url("/blah/blah/5", arg: "new", id: 4))
  end

  def test_add_args_to_url_valid_utf_8_address_and_arg
    assert_equal("/voilà?arg=a%C4%8D%E2%82%AC%CE%B5nt",
                 add_args_to_url("/voilà", arg: "ač€εnt"))
  end

  def test_add_args_to_url_invalid_utf_8_address_and_arg
    assert_equal("/blah\x80",
                 add_args_to_url("/blah\x80", x: "foo\xA0"))
  end

  # Test that array params (like q[by_user][]=1&q[by_user][]=2) are preserved
  def test_add_args_to_url_preserves_array_params
    # "q%5Bby_user%5D%5B%5D=1&q%5Bby_user%5D%5B%5D=2"
    query_string = { q: { by_user: [1, 2] } }.to_query
    url = "/observations?#{query_string}"
    result = add_args_to_url(url, page: 2)

    # The result should contain both by_user values
    # "q%5Bby_user%5D%5B%5D=1"
    by_user_1 = { q: { by_user: [1] } }.to_query
    # "q%5Bby_user%5D%5B%5D=2"
    by_user_2 = { q: { by_user: [2] } }.to_query
    assert_includes(result, by_user_1, "Should preserve first array value")
    assert_includes(result, by_user_2, "Should preserve second array value")
    assert_includes(result, "page=2", "Should add new page param")
  end

  def test_add_args_to_url_with_active_record_value
    obs = observations(:minimal_unknown_obs)

    result = add_args_to_url("/observations", target: obs)

    assert_includes(result, "target=#{obs.id}",
                    "ActiveRecord value should be serialized as its id")
  end

  def test_user_status_string_admin_mode
    stub(:in_admin_mode?, true) do
      assert_equal("admin_mode", user_status_string,
                   "Expected admin_mode when in_admin_mode? is true")
    end
  end

  def test_user_status_string_robot
    bot_browser = Object.new
    bot_browser.define_singleton_method(:bot?) { true }

    stub(:in_admin_mode?, false) do
      stub(:browser, bot_browser) do
        assert_equal("robot", user_status_string,
                     "Expected robot when browser is a bot")
      end
    end
  end

  def test_user_status_string_logged_in
    non_bot = Object.new
    non_bot.define_singleton_method(:bot?) { false }

    stub(:in_admin_mode?, false) do
      stub(:browser, non_bot) do
        assert_equal("logged_in", user_status_string(users(:rolf)),
                     "Expected logged_in when user is present")
      end
    end
  end

  def test_user_status_string_no_user
    non_bot = Object.new
    non_bot.define_singleton_method(:bot?) { false }

    stub(:in_admin_mode?, false) do
      stub(:browser, non_bot) do
        assert_equal("no_user", user_status_string(nil),
                     "Expected no_user when user is nil")
      end
    end
  end

  def test_logged_in_status_when_logged_in
    User.current = users(:rolf)
    assert_equal("logged_in", logged_in_status,
                 "Expected logged_in when User.current is set")
  ensure
    User.current = nil
  end

  def test_logged_in_status_when_not_logged_in
    User.current = nil
    assert_equal("no_user", logged_in_status,
                 "Expected no_user when User.current is nil")
  end

  def test_form_submit_text_new_record
    obj = Observation.new
    expected_type = obj.class.model_name.singular.upcase.to_sym.t

    assert_equal(:create_object.t(TYPE: expected_type),
                 form_submit_text(obj),
                 "Expected create label for new record")
  end

  def test_form_submit_text_existing_record
    obj = observations(:minimal_unknown_obs)
    expected_type = obj.class.model_name.singular.upcase.to_sym.t

    assert_equal(:update_object.t(TYPE: expected_type),
                 form_submit_text(obj),
                 "Expected update label for persisted record")
  end
end
