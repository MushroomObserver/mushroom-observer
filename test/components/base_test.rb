# frozen_string_literal: true

require "test_helper"

class BaseTest < ComponentTestCase
  # Simple test component to test trusted_html method
  class TestComponent < Components::Base
    def view_template
      div do
        trusted_html("plain text")
      end
    end
  end

  # Test component that uses SafeBuffer
  class TestSafeBufferComponent < Components::Base
    def view_template
      div do
        trusted_html("safe <strong>html</strong>".html_safe)
      end
    end
  end

  # Reads the registered `current_user` value helper. Used by the
  # `Components::Base.current_user` tests below.
  class CurrentUserReader < Components::Base
    def view_template
      plain(current_user&.login || "nobody")
    end
  end

  # Reads the registered `current_query` value helper. Used by the
  # `Components::Base.current_query` tests below.
  class CurrentQueryReader < Components::Base
    def view_template
      plain(current_query&.id&.to_s || "no-query")
    end
  end

  def test_trusted_html_with_plain_string
    html = render_component(TestComponent.new)
    doc = Nokogiri::HTML(html)
    div = doc.at_css("div")

    assert_equal("plain text", div.text)
    # Verify no HTML tags were rendered
    assert_not(div.inner_html.include?("<"))
  end

  def test_trusted_html_with_safe_buffer
    html = render_component(TestSafeBufferComponent.new)
    doc = Nokogiri::HTML(html)
    div = doc.at_css("div")
    strong = div.at_css("strong")

    assert_not_nil(strong)
    assert_equal("html", strong.text)
    assert_equal("safe html", div.text.strip)
  end

  def test_nbsp_emits_non_breaking_space_entity
    html = render(Class.new(Components::Base) do
                    def view_template = span { nbsp }
                  end.new)

    assert_html(html, "span", text: "&nbsp;".as_displayed)
  end

  def test_cache_store_returns_rails_cache
    component = TestComponent.new
    assert_equal(Rails.cache, component.cache_store)
  end

  # The before_template hook emits a "<!-- Before ClassName -->"
  # comment in development so reviewers can see which component
  # rendered which DOM region; in test/prod it's a no-op.
  def test_before_template_adds_comment_in_development
    Rails.env.stub(:development?, true) do
      html = render_component(TestComponent.new)

      assert_includes(html, "<!--")
      assert_includes(html, "Before #{TestComponent.name}")
    end
  end

  def test_before_template_no_comment_outside_development
    html = render_component(TestComponent.new)

    assert_not_includes(html, "<!-- Before")
  end

  # `current_user` is a `register_value_helper`'d alias for the
  # controller's `@user`; views call it instead of taking a
  # `prop :user, _Nilable(::User)` when they only need "the viewer".
  def test_current_user_reads_controllers_user_ivar
    user = users(:rolf)
    controller.instance_variable_set(:@user, user)

    assert_equal(user.login, render(CurrentUserReader.new))
  end

  def test_current_user_is_nil_when_no_one_logged_in
    controller.instance_variable_set(:@user, nil)

    assert_equal("nobody", render(CurrentUserReader.new))
  end

  # `current_query` is a `register_value_helper`'d alias for
  # `controller.current_query` — the typed `Query` view a Phlex view
  # can fall back to when its `prop :query, _Nilable(::Query)` isn't
  # passed, without round-tripping through the URL's q param.
  def test_current_query_reads_controllers_current_query
    query = ::Query.lookup_and_save(:Observation)
    controller.instance_variable_set(:@query, query)

    assert_equal(query.id.to_s, render(CurrentQueryReader.new))
  end

  def test_current_query_is_nil_when_no_query_on_controller
    controller.instance_variable_set(:@query, nil)

    assert_equal("no-query", render(CurrentQueryReader.new))
  end

  # ----- add_args_to_url -----------------------------------------------

  # `add_args_to_url(url, new_args)` lives on `Components::Base` as a
  # plain instance method — these tests call it via a renderless
  # subclass (`Components::Base.new`) since `add_args_to_url` doesn't
  # depend on Phlex render state, just on `Rack::Utils` + Ruby.
  def adder
    @adder ||= Class.new(Components::Base).new
  end

  def test_add_args_to_url_two_args
    assert_equal("/abcdef?foo=bar&this=that",
                 adder.add_args_to_url("/abcdef",
                                       foo: "bar", this: "that"))
  end

  def test_add_args_to_url_arg_replaces_url_parameter
    assert_equal("/abcdef?foo=bar&this=that",
                 adder.add_args_to_url("/abcdef?foo=wrong",
                                       foo: "bar", this: "that"))
  end

  def test_add_args_to_url_append_args_to_url
    result = adder.add_args_to_url("/abcdef?foo=wrong&a=2",
                                   foo: '"bar"', this: "that")
    assert(result.start_with?("/abcdef?"), "Should start with path")
    assert_includes(result, "a=2", "Should preserve existing param")
    assert_includes(result, "foo=%22bar%22", "Should replace foo param")
    assert_includes(result, "this=that", "Should add new param")
  end

  def test_add_args_to_url_ending_with_id
    assert_equal("/blah/blah/5?arg=new",
                 adder.add_args_to_url("/blah/blah/5", arg: "new"))
  end

  def test_add_args_to_url_id_arg_replaces_id_in_url
    assert_equal("/blah/blah/4?arg=new",
                 adder.add_args_to_url("/blah/blah/5",
                                       arg: "new", id: 4))
  end

  def test_add_args_to_url_valid_utf_8_address_and_arg
    assert_equal("/voilà?arg=a%C4%8D%E2%82%AC%CE%B5nt",
                 adder.add_args_to_url("/voilà", arg: "ač€εnt"))
  end

  def test_add_args_to_url_invalid_utf_8_address_and_arg
    assert_equal("/blah\x80",
                 adder.add_args_to_url("/blah\x80", x: "foo\xA0"))
  end

  # Array params (`q[by_user][]=1&q[by_user][]=2`) must round-trip.
  def test_add_args_to_url_preserves_array_params
    query_string = { q: { by_user: [1, 2] } }.to_query
    url = "/observations?#{query_string}"

    result = adder.add_args_to_url(url, page: 2)

    by_user_1 = { q: { by_user: [1] } }.to_query
    by_user_2 = { q: { by_user: [2] } }.to_query
    assert_includes(result, by_user_1, "Should preserve first array value")
    assert_includes(result, by_user_2, "Should preserve second array value")
    assert_includes(result, "page=2", "Should add new page param")
  end

  def test_add_args_to_url_with_active_record_value
    obs = observations(:minimal_unknown_obs)

    result = adder.add_args_to_url("/observations", target: obs)

    assert_includes(result, "target=#{obs.id}",
                    "ActiveRecord value should be serialized as its id")
  end
end
