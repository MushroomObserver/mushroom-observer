# frozen_string_literal: true

require "test_helper"

class MatrixBoxTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
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

  # Test HTML structure and nesting
  def test_wraps_panel_in_list_item
    obs = observations(:coprinus_comatus_obs)
    component = Components::MatrixBox.new(user: @user, object: obs)
    html = render(component)

    # Should have li.matrix-box containing div.panel
    assert_nested(
      html,
      parent_selector: "li.matrix-box",
      child_selector: "div.panel"
    )
  end

  def test_panel_has_sizing_wrapper
    obs = observations(:coprinus_comatus_obs)
    component = Components::MatrixBox.new(user: @user, object: obs)
    html = render(component)

    # Panel should have panel-sizing wrapper (from sizing: true)
    assert_includes(html, "panel-sizing")
    assert_nested(
      html,
      parent_selector: "div.panel-sizing",
      child_selector: "div.thumbnail-container"
    )
  end

  def test_thumbnail_nested_in_panel_thumbnail_section
    obs = observations(:coprinus_comatus_obs)
    component = Components::MatrixBox.new(user: @user, object: obs)
    html = render(component)

    # Thumbnail should be in thumbnail-container within panel-sizing
    assert_nested(
      html,
      parent_selector: "div.panel-sizing",
      child_selector: "div.thumbnail-container"
    )
    # Should contain the image
    assert_nested(
      html,
      parent_selector: "div.thumbnail-container",
      child_selector: "img"
    )
  end

  def test_details_section_has_correct_class
    obs = observations(:coprinus_comatus_obs)
    component = Components::MatrixBox.new(user: @user, object: obs)
    html = render(component)

    # Details section should have rss-box-details class
    assert_includes(html, "rss-box-details")
    assert_nested(
      html,
      parent_selector: "div.panel-body.rss-box-details",
      child_selector: "div.rss-what"
    )
  end

  def test_renders_what_where_when_sections_in_body
    obs = observations(:coprinus_comatus_obs)
    component = Components::MatrixBox.new(user: @user, object: obs)
    html = render(component)

    # Should have what section in panel-body
    assert_nested(
      html,
      parent_selector: "div.panel-body.rss-box-details",
      child_selector: "div.rss-what"
    )
    # Should have where section in panel-body
    assert_nested(
      html,
      parent_selector: "div.panel-body.rss-box-details",
      child_selector: "div.rss-where"
    )
    # Should have when/who info (rendered with rss-when and rss-who classes)
    assert_includes(html, "rss-when")
    assert_includes(html, "rss-who")
  end

  def test_observation_title_includes_name
    obs = observations(:coprinus_comatus_obs)
    component = Components::MatrixBox.new(user: @user, object: obs)
    html = render(component)

    # Should include observation name in the what section
    assert_text_in_nested_selector(
      html,
      text: obs.name.text_name,
      parent: "div.rss-what",
      child: "h5"
    )
  end

  def test_observation_includes_location
    obs = observations(:coprinus_comatus_obs)
    component = Components::MatrixBox.new(user: @user, object: obs)
    html = render(component)

    # Should include location in where section
    assert_includes(html, obs.where)
  end

  def test_rss_log_renders_footer
    # Find an RssLog with detail or time
    rss_log = RssLog.where.not(observation_id: nil).first
    skip("No RssLog found for testing") unless rss_log

    component = Components::MatrixBox.new(user: @user, object: rss_log)
    html = render(component)

    # RssLogs should have log-footer
    assert_includes(html, "log-footer")
    assert_nested(
      html,
      parent_selector: "div.panel",
      child_selector: "div.panel-footer.log-footer"
    )
  end

  # NOTE: identify mode tests require permission? helper which needs
  # complex test setup. These features are tested in integration tests.

  def test_image_object_structure
    image = images(:connected_coprinus_comatus_image)
    component = Components::MatrixBox.new(user: @user, object: image)
    html = render(component)

    # Should have panel structure
    assert_nested(
      html,
      parent_selector: "li#box_#{image.id}",
      child_selector: "div.panel"
    )
    # Should have thumbnail
    assert_nested(
      html,
      parent_selector: "div.thumbnail-container",
      child_selector: "img"
    )
  end

  def test_user_object_structure
    user = users(:katrina)
    component = Components::MatrixBox.new(user: @user, object: user)
    html = render(component)

    # Should have panel structure
    assert_nested(
      html,
      parent_selector: "li#box_#{user.id}",
      child_selector: "div.panel"
    )
    # Should have user info in body
    assert_nested(
      html,
      parent_selector: "div.panel-body",
      child_selector: "div.rss-what"
    )
  end

  def test_does_not_render_identify_ui_and_footer_when_identify_is_false
    obs = observations(:coprinus_comatus_obs)
    component = Components::MatrixBox.new(
      user: @user,
      object: obs,
      identify: false
    )
    html = render(component)

    # Should not have identify UI (vote container or propose naming link)
    assert_not_includes(html, "vote-select-container")
    assert_not_includes(html, "context=matrix_box")
    # Should not have identify footer
    assert_not_includes(html, "panel-active")
    assert_not_includes(html, "box_reviewed")
  end

  def test_renders_identify_ui_and_footer_when_identify_is_true
    # Must eager-load observation_views for identify footer to render
    obs = Observation.includes(:observation_views).
          find(observations(:coprinus_comatus_obs).id)
    component = Components::MatrixBox.new(
      user: @user,
      object: obs,
      identify: true
    )
    html = render(component)

    # Should have identify UI (vote container or propose naming link)
    assert(
      html.include?("vote-select-container") ||
        html.include?("context=matrix_box"),
      "Expected identify UI to be rendered"
    )
    # Should have identify footer
    assert_includes(html, "panel-active")
    assert_includes(html, "box_reviewed")
  end
end
