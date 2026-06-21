# frozen_string_literal: true

require("test_helper")

# Covers Tab::Base default behavior — the bits subclasses inherit
# unchanged. Subclass-specific behavior is exercised in each
# domain's `tabs_test.rb`.
module Tab
  class BaseTest < UnitTestCase
    # Subclass with no overrides — exercises the NotImplementedError
    # branches on title + path, and the demodulized class-name
    # fallback on nav_key.
    class Bare < Tab::Base
    end

    class WithUnknownKey < Tab::Base
      def title = "Foo"
      def path  = "/foo"
      def html_options = { tooltip: "bad" }
    end

    class WithBadButtonValue < Tab::Base
      def title = "Bar"
      def path  = "/bar"
      def html_options = { button: :link }
    end

    def test_title_raises_not_implemented
      e = assert_raises(NotImplementedError) { Bare.new.title }

      assert_match(/Bare#title/, e.message)
    end

    def test_path_raises_not_implemented
      e = assert_raises(NotImplementedError) { Bare.new.path }

      assert_match(/Bare#path/, e.message)
    end

    def test_nav_key_demodulizes_class_name_when_alt_title_nil
      # Bare.alt_title returns nil (inherited Tab::Base default), so
      # nav_key falls through to the demodulized + underscored class
      # name. `Tab::BaseTest::Bare` → "bare".
      assert_equal("bare", Bare.new.nav_key)
    end

    def test_html_options_raises_on_unknown_key
      e = assert_raises(ArgumentError) { WithUnknownKey.new.html_options }

      assert_match(/unknown key/, e.message)
      assert_match(/:tooltip/, e.message)
    end

    def test_html_options_raises_on_invalid_button_value
      e = assert_raises(ArgumentError) { WithBadButtonValue.new.html_options }

      assert_match(/:button must be/, e.message)
      assert_match(/:link/, e.message)
    end
  end
end
