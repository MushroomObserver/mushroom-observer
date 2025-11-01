# frozen_string_literal: true

require "test_helper"

class MatrixBoxTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @user = users(:rolf)
  end

  def test_renders_observation_with_thumbnail
    obs = observations(:coprinus_comatus_obs)
    component = Components::MatrixBox.new(user: @user, object: obs)
    html = render(component)

    assert_includes(html, "matrix-box")
    assert_includes(html, "box_#{obs.id}")
    # Should include the thumbnail image with the correct CSS class
    assert_includes(html, "image_#{obs.thumb_image_id}")
  end

  def test_renders_observation_without_thumbnail
    obs = observations(:minimal_unknown_obs)
    component = Components::MatrixBox.new(user: @user, object: obs)
    html = render(component)

    assert_includes(html, "matrix-box")
    assert_includes(html, "box_#{obs.id}")
  end

  def test_renders_image_object
    image = images(:connected_coprinus_comatus_image)
    component = Components::MatrixBox.new(user: @user, object: image)
    html = render(component)

    assert_includes(html, "matrix-box")
    assert_includes(html, "box_#{image.id}")
    assert_includes(html, "image_#{image.id}")
  end

  def test_renders_user_object
    user = users(:katrina)
    component = Components::MatrixBox.new(user: @user, object: user)
    html = render(component)

    assert_includes(html, "matrix-box")
    assert_includes(html, "box_#{user.id}")
  end

  def test_renders_rss_log_with_observation_target
    rss_log = RssLog.where.not(observation_id: nil).first
    component = Components::MatrixBox.new(user: @user, object: rss_log)
    html = render(component)

    assert_includes(html, "matrix-box")
  end

  def test_renders_with_custom_columns
    obs = observations(:coprinus_comatus_obs)
    component = Components::MatrixBox.new(
      user: @user,
      object: obs,
      columns: "col-xs-12 col-sm-6"
    )
    html = render(component)

    assert_includes(html, "col-xs-12 col-sm-6")
  end

  def test_renders_with_extra_class
    obs = observations(:coprinus_comatus_obs)
    component = Components::MatrixBox.new(
      user: @user,
      object: obs,
      extra_class: "custom-class"
    )
    html = render(component)

    assert_includes(html, "custom-class")
  end

  # NOTE: Testing custom block content requires Phlex DSL context
  # This test is commented out as it requires the block to be evaluated
  # in the component's Phlex context, not the test context
  # def test_renders_custom_block_content
  #   component = Components::MatrixBox.new(id: 123, extra_class: "test-cls") do
  #     div { "Custom content" }
  #   end
  #   html = render(component)
  #
  #   assert_includes(html, "box_123")
  #   assert_includes(html, "test-class")
  #   assert_includes(html, "Custom content")
  # end
end
