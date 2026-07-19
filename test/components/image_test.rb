# frozen_string_literal: true

require "test_helper"

# Components::Image is a hand-off to Components::Image::Interactive,
# purely so callers get Kit syntax. See Components::Image::InteractiveTest
# for actual rendering-behavior coverage.
class Components::ImageTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @image = images(:connected_coprinus_comatus_image)
  end

  def test_new_returns_an_interactive_instance
    instance = Components::Image.new(user: @user, image: @image)

    assert_instance_of(Components::Image::Interactive, instance)
  end

  def test_kit_syntax_renders_same_as_interactive
    view = Class.new(Components::Base) do
      def initialize(user:, image:)
        super()
        @user = user
        @image = image
      end

      def view_template
        Image(user: @user, image: @image, votes: false)
      end
    end

    html = render(view.new(user: @user, image: @image))
    interactive_html = render(
      Components::Image::Interactive.new(
        user: @user, image: @image, votes: false
      )
    )

    assert_equal(interactive_html, html)
  end
end
