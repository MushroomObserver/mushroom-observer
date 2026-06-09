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
end
