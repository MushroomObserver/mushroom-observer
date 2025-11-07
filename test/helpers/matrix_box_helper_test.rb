# frozen_string_literal: true

require("test_helper")

# Test the matrix_box_helper methods
class MatrixBoxHelperTest < ActionView::TestCase
  def setup
    @user = users(:rolf)
  end

  # Tests for should_cache_object?

  def test_should_cache_object_with_transferred_image
    obs = observations(:coprinus_comatus_obs)
    # Stub transferred to return true
    obs.thumb_image.stub(:transferred, true) do
      assert(
        should_cache_object?(obs),
        "Expected should_cache_object? to return true for transferred image"
      )
    end
  end

  def test_should_not_cache_object_with_untransferred_image
    obs = observations(:coprinus_comatus_obs)
    # Stub transferred to return false
    obs.thumb_image.stub(:transferred, false) do
      assert_not(
        should_cache_object?(obs),
        "Expected should_cache_object? to return false for untransferred image"
      )
    end
  end

  def test_should_cache_object_with_nil_thumb_image
    obs = observations(:minimal_unknown_obs)
    assert_nil(
      obs.thumb_image,
      "Test requires observation with nil thumb_image"
    )

    assert(
      should_cache_object?(obs),
      "Expected should_cache_object? to return true when thumb_image is nil"
    )
  end

  def test_should_cache_object_without_thumb_image_method
    user = users(:katrina)
    assert_not(
      user.respond_to?(:thumb_image),
      "Test requires object without thumb_image method"
    )

    assert(
      should_cache_object?(user),
      "Expected should_cache_object? to return true for objects without " \
      "thumb_image"
    )
  end

  # Tests for render_cached_matrix_boxes

  def test_render_cached_matrix_boxes_caches_transferred_images
    obs = observations(:coprinus_comatus_obs)
    # Stub transferred to return true
    obs.thumb_image.stub(:transferred, true) do
      cache_called = false
      # Stub both cache, render, and concat to avoid actual rendering
      stub(:cache, lambda { |_obj, &block|
        cache_called = true
        block.call
      }) do
        stub(:render, "") do
          stub(:concat, nil) do
            render_cached_matrix_boxes([obs], {})
          end
        end
      end

      assert(
        cache_called,
        "Expected cache to be called for transferred image"
      )
    end
  end

  def test_render_cached_matrix_boxes_does_not_cache_untransferred_images
    obs = observations(:coprinus_comatus_obs)
    # Stub transferred to return false
    obs.thumb_image.stub(:transferred, false) do
      cache_called = false
      # Stub both cache, render, and concat to avoid actual rendering
      stub(:cache, lambda { |_obj, &block|
        cache_called = true
        block.call
      }) do
        stub(:render, "") do
          stub(:concat, nil) do
            render_cached_matrix_boxes([obs], {})
          end
        end
      end

      assert_not(
        cache_called,
        "Expected cache NOT to be called for untransferred image"
      )
    end
  end

  def test_render_cached_matrix_boxes_caches_nil_thumb_image
    obs = observations(:minimal_unknown_obs)
    assert_nil(
      obs.thumb_image,
      "Test requires observation with nil thumb_image"
    )

    cache_called = false
    # Stub both cache, render, and concat to avoid actual rendering
    stub(:cache, lambda { |_obj, &block|
      cache_called = true
      block.call
    }) do
      stub(:render, "") do
        stub(:concat, nil) do
          render_cached_matrix_boxes([obs], {})
        end
      end
    end

    assert(
      cache_called,
      "Expected cache to be called when thumb_image is nil"
    )
  end

  def test_render_cached_matrix_boxes_caches_objects_without_thumb_image
    user = users(:katrina)
    assert_not(
      user.respond_to?(:thumb_image),
      "Test requires object without thumb_image method"
    )

    cache_called = false
    # Stub both cache, render, and concat to avoid actual rendering
    stub(:cache, lambda { |_obj, &block|
      cache_called = true
      block.call
    }) do
      stub(:render, "") do
        stub(:concat, nil) do
          render_cached_matrix_boxes([user], {})
        end
      end
    end

    assert(
      cache_called,
      "Expected cache to be called for objects without thumb_image"
    )
  end

  def test_render_cached_matrix_boxes_handles_multiple_objects
    obs1 = observations(:coprinus_comatus_obs)
    obs2 = observations(:agaricus_campestris_obs)

    # One transferred, one not
    obs1.thumb_image.stub(:transferred, true) do
      obs2.thumb_image.stub(:transferred, false) do
        cache_call_count = 0
        # Stub both cache, render, and concat to avoid actual rendering
        stub(:cache, lambda { |_obj, &block|
          cache_call_count += 1
          block.call
        }) do
          stub(:render, "") do
            stub(:concat, nil) do
              render_cached_matrix_boxes([obs1, obs2], {})
            end
          end
        end

        assert_equal(
          1,
          cache_call_count,
          "Expected cache to be called once (only for transferred image)"
        )
      end
    end
  end
end
