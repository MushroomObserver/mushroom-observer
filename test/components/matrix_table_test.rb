# frozen_string_literal: true

require "test_helper"

class MatrixTableTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @user = users(:rolf)
  end

  def test_renders_empty_table_when_no_objects
    component = Components::MatrixTable.new
    html = render(component)

    assert_includes(html, "list-unstyled")
    assert_includes(html, "matrix-table")
  end

  def test_renders_observations_without_caching
    observations = [
      observations(:coprinus_comatus_obs),
      observations(:agaricus_campestris_obs)
    ]
    component = Components::MatrixTable.new(
      objects: observations,
      user: @user,
      cached: false
    )
    html = render(component)

    assert_includes(html, "box_#{observations.first.id}")
    assert_includes(html, "box_#{observations.second.id}")
  end

  def test_caches_observations_with_transferred_images
    obs = observations(:coprinus_comatus_obs)
    # Stub transferred to return true
    obs.thumb_image.stub(:transferred, true) do
      component = Components::MatrixTable.new(
        objects: [obs],
        user: @user,
        cached: true
      )

      # Expect cache to be called
      cache_called = false
      component.stub(:cache, lambda { |_obj, &block|
        cache_called = true
        block.call
      }) do
        render(component)
      end

      assert(cache_called, "Expected cache to be called for transferred image")
    end
  end

  def test_does_not_cache_observations_with_untransferred_images
    obs = observations(:coprinus_comatus_obs)
    # Stub transferred to return false
    obs.thumb_image.stub(:transferred, false) do
      component = Components::MatrixTable.new(
        objects: [obs],
        user: @user,
        cached: true
      )

      # Expect cache NOT to be called
      cache_called = false
      component.stub(:cache, lambda { |_obj, &block|
        cache_called = true
        block.call
      }) do
        html = render(component)
        # Should still render the box, just not cached
        assert_includes(html, "box_#{obs.id}")
      end

      assert_not(
        cache_called,
        "Expected cache NOT to be called for untransferred image"
      )
    end
  end

  def test_caches_objects_without_thumb_image
    user = users(:katrina)
    component = Components::MatrixTable.new(
      objects: [user],
      user: @user,
      cached: true
    )

    # Expect cache to be called for user objects
    cache_called = false
    component.stub(:cache, lambda { |_obj, &block|
      cache_called = true
      block.call
    }) do
      render(component)
    end

    assert(
      cache_called,
      "Expected cache to be called for objects without thumb_image"
    )
  end

  def test_caches_observations_with_nil_thumb_image
    obs = observations(:minimal_unknown_obs)
    assert_nil(obs.thumb_image,
               "Test requires observation with nil thumb_image")

    component = Components::MatrixTable.new(
      objects: [obs],
      user: @user,
      cached: true
    )

    # Expect cache to be called when thumb_image is nil
    cache_called = false
    component.stub(:cache, lambda { |_obj, &block|
      cache_called = true
      block.call
    }) do
      render(component)
    end

    assert(
      cache_called,
      "Expected cache to be called when thumb_image is nil"
    )
  end

  def test_does_not_render_identify_ui_and_footer_when_identify_is_false
    obs = observations(:coprinus_comatus_obs)
    component = Components::MatrixTable.new(
      objects: [obs],
      user: @user,
      identify: false
    )
    html = render(component)

    # Should not have identify UI or footer
    assert_not_includes(html, "vote-select-container")
    assert_not_includes(html, "context=matrix_box")
    assert_not_includes(html, "panel-active")
    assert_not_includes(html, "box_reviewed")
  end

  def test_renders_identify_ui_and_footer_when_identify_is_true
    # Must eager-load observation_views for identify footer to render
    obs = Observation.includes(:observation_views).
          find(observations(:coprinus_comatus_obs).id)
    component = Components::MatrixTable.new(
      objects: [obs],
      user: @user,
      identify: true
    )
    html = render(component)

    # Should have identify UI and footer
    assert(
      html.include?("vote-select-container") ||
        html.include?("context=matrix_box"),
      "Expected identify UI to be rendered"
    )
    assert_includes(html, "panel-active")
    assert_includes(html, "box_reviewed")
  end

  def test_renders_with_block
    component = Components::MatrixTable.new
    html = render(component) do |table|
      table.render(
        Components::MatrixBox.new(
          id: 123,
          extra_class: "block-test"
        ) do
          view_context.tag.div(class: "panel panel-default") do
            "Custom content"
          end
        end
      )
    end

    assert_includes(html, "box_123")
    assert_includes(html, "block-test")
    assert_includes(html, "Custom content")
  end

  def test_cache_key_includes_locale
    obs = observations(:coprinus_comatus_obs)
    obs.thumb_image.stub(:transferred, true) do
      component = Components::MatrixTable.new(
        objects: [obs],
        user: @user,
        cached: true
      )

      # Capture the cache key that gets passed to cache()
      captured_key = nil
      component.stub(:cache, lambda { |key, &block|
        captured_key = key
        block.call
      }) do
        render(component)
      end

      assert_equal([I18n.locale, obs], captured_key,
                   "Cache key should include locale and object")
    end
  end

  def test_different_locales_use_different_cache_keys
    obs = observations(:coprinus_comatus_obs)
    obs.thumb_image.stub(:transferred, true) do
      keys = []

      # Render with English locale
      component_en = Components::MatrixTable.new(
        objects: [obs], user: @user, cached: true
      )
      component_en.stub(:cache, lambda { |key, &block|
        keys << key
        block.call
      }) do
        I18n.with_locale(:en) { render(component_en) }
      end

      # Render with Spanish locale (new component instance)
      component_es = Components::MatrixTable.new(
        objects: [obs], user: @user, cached: true
      )
      component_es.stub(:cache, lambda { |key, &block|
        keys << key
        block.call
      }) do
        I18n.with_locale(:es) { render(component_es) }
      end

      assert_equal([:en, obs], keys[0], "First key should use :en locale")
      assert_equal([:es, obs], keys[1], "Second key should use :es locale")
      assert_not_equal(keys[0], keys[1], "Different locales should have " \
                                         "different cache keys")
    end
  end
end
