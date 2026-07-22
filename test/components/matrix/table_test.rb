# frozen_string_literal: true

require "test_helper"

class MatrixTableTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  def test_renders_empty_table_when_no_objects
    component = Components::Matrix::Table.new
    html = render(component)

    assert_includes(html, "list-unstyled")
    assert_includes(html, "matrix-table")
  end

  def test_renders_observations_without_caching
    observations = [
      observations(:coprinus_comatus_obs),
      observations(:agaricus_campestris_obs)
    ]
    component = Components::Matrix::Table.new(
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
      component = Components::Matrix::Table.new(
        objects: [obs],
        user: @user,
        cached: true
      )

      # Expect cache to be called
      cache_called = false
      component.stub(:low_level_cache, lambda { |_key, &block|
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
      component = Components::Matrix::Table.new(
        objects: [obs],
        user: @user,
        cached: true
      )

      # Expect cache NOT to be called
      cache_called = false
      component.stub(:low_level_cache, lambda { |_key, &block|
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
    component = Components::Matrix::Table.new(
      objects: [user],
      user: @user,
      cached: true
    )

    # Expect cache to be called for user objects
    cache_called = false
    component.stub(:low_level_cache, lambda { |_key, &block|
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

  # A bare Image object (images/index's matrix table) has no
  # `thumb_image` to defer to -- it IS the thumb. should_cache_object?
  # must check the Image's own `transferred` directly instead of
  # falling through the `respond_to?(:thumb_image)` guard to an
  # unconditional true (the gap this test guards against).
  def test_caches_image_objects_with_transferred_true
    image = images(:connected_coprinus_comatus_image)
    image.stub(:transferred, true) do
      component = Components::Matrix::Table.new(
        objects: [image], user: @user, cached: true
      )

      cache_called = false
      component.stub(:low_level_cache, lambda { |_key, &block|
        cache_called = true
        block.call
      }) do
        render(component)
      end

      assert(cache_called,
             "Expected cache to be called for a transferred Image object")
    end
  end

  def test_does_not_cache_image_objects_with_transferred_false
    image = images(:connected_coprinus_comatus_image)
    image.stub(:transferred, false) do
      component = Components::Matrix::Table.new(
        objects: [image], user: @user, cached: true
      )

      cache_called = false
      component.stub(:low_level_cache, lambda { |_key, &block|
        cache_called = true
        block.call
      }) do
        html = render(component)
        assert_includes(html, "box_#{image.id}")
      end

      assert_not(cache_called,
                 "Expected cache NOT to be called for an untransferred " \
                 "Image object")
    end
  end

  # cache_key_for folds in the thumb image record so the expanded key
  # tracks the thumb's updated_at (its cache_key embeds the timestamp)
  # -- reprocessing bumps it, and the cached HTML embeds a URL token
  # derived from it (#4808). Nothing touches an RssLog when its thumb
  # finishes processing, so the thumb must appear in the key itself.
  def test_cache_key_for_includes_the_thumb_image_record
    obs = observations(:coprinus_comatus_obs)

    key = Components::Matrix::Table.cache_key_for(obs, I18n.locale)

    assert_equal(
      ["MatrixBox", Components::Matrix::Table::CACHE_VERSION,
       I18n.locale, obs, obs.thumb_image],
      key
    )

    # The expanded key must change when the thumb's updated_at does --
    # this is the mechanism the fragment busting relies on.
    store = ActiveSupport::Cache::MemoryStore.new
    old_expanded = store.send(:normalize_key, key, {})
    obs.thumb_image.updated_at += 1.hour
    new_expanded = store.send(
      :normalize_key,
      Components::Matrix::Table.cache_key_for(obs, I18n.locale), {}
    )

    assert_not_equal(old_expanded, new_expanded)
  end

  # A bare Image object IS its own thumb: it has no thumb_image, and
  # its own timestamp already participates in the key via `object`.
  def test_cache_key_for_image_object_keys_on_the_image_itself
    image = images(:connected_coprinus_comatus_image)

    key = Components::Matrix::Table.cache_key_for(image, I18n.locale)

    assert_equal(
      ["MatrixBox", Components::Matrix::Table::CACHE_VERSION,
       I18n.locale, image, nil],
      key
    )
  end

  def test_caches_observations_with_nil_thumb_image
    obs = observations(:minimal_unknown_obs)
    assert_nil(obs.thumb_image,
               "Test requires observation with nil thumb_image")

    component = Components::Matrix::Table.new(
      objects: [obs],
      user: @user,
      cached: true
    )

    # Expect cache to be called when thumb_image is nil
    cache_called = false
    component.stub(:low_level_cache, lambda { |_key, &block|
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
    component = Components::Matrix::Table.new(
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
    component = Components::Matrix::Table.new(
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
    component = Components::Matrix::Table.new
    html = render(component) do |table|
      table.render(
        Components::Matrix::Box.new(
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
      component = Components::Matrix::Table.new(
        objects: [obs],
        user: @user,
        cached: true
      )

      # Capture the cache key that gets passed to low_level_cache
      captured_key = nil
      component.stub(:low_level_cache, lambda { |key, &block|
        captured_key = key
        block.call
      }) do
        render(component)
      end

      assert_equal(
        Components::Matrix::Table.cache_key_for(obs, I18n.locale),
        captured_key,
        "Cache key should match `MatrixTable.cache_key_for(obj, locale)`"
      )
    end
  end

  def test_does_not_cache_when_identify_is_true
    obs = observations(:coprinus_comatus_obs)
    obs.thumb_image.stub(:transferred, true) do
      component = Components::Matrix::Table.new(
        objects: [obs],
        user: @user,
        cached: true,
        identify: true
      )

      cache_called = false
      component.stub(:low_level_cache, lambda { |_key, &block|
        cache_called = true
        block.call
      }) do
        html = render(component)
        assert_includes(html, "box_#{obs.id}")
      end

      assert_not(
        cache_called,
        "Expected cache NOT to be called in identify mode"
      )
    end
  end

  def test_different_locales_use_different_cache_keys
    obs = observations(:coprinus_comatus_obs)
    obs.thumb_image.stub(:transferred, true) do
      keys = []

      # Render with English locale
      component_en = Components::Matrix::Table.new(
        objects: [obs], user: @user, cached: true
      )
      component_en.stub(:low_level_cache, lambda { |key, &block|
        keys << key
        block.call
      }) do
        I18n.with_locale(:en) { render(component_en) }
      end

      # Render with Spanish locale (new component instance)
      component_es = Components::Matrix::Table.new(
        objects: [obs], user: @user, cached: true
      )
      component_es.stub(:low_level_cache, lambda { |key, &block|
        keys << key
        block.call
      }) do
        I18n.with_locale(:es) { render(component_es) }
      end

      assert_equal(Components::Matrix::Table.cache_key_for(obs, :en),
                   keys[0], "First key should use :en locale")
      assert_equal(Components::Matrix::Table.cache_key_for(obs, :es),
                   keys[1], "Second key should use :es locale")
      assert_not_equal(keys[0], keys[1], "Different locales should have " \
                                         "different cache keys")
    end
  end

  # Counts read_multi/write_multi calls so the batching tests below can
  # assert exactly one round trip regardless of object count.
  class CountingCacheStore
    attr_reader :read_multi_calls, :write_multi_calls

    def initialize(real_store)
      @real_store = real_store
      @read_multi_calls = 0
      @write_multi_calls = 0
    end

    def read_multi(*keys)
      @read_multi_calls += 1
      @real_store.read_multi(*keys)
    end

    def write_multi(hash)
      @write_multi_calls += 1
      @real_store.write_multi(hash)
    end

    delegate :read, :write, to: :@real_store
  end

  def test_render_cached_boxes_resolves_a_hit_and_a_miss_in_one_round_trip
    observations = [
      observations(:coprinus_comatus_obs),
      observations(:agaricus_campestris_obs)
    ]
    observations.each do |obs|
      obs.thumb_image.update_column(:transferred, true)
    end

    real_store = ActiveSupport::Cache::MemoryStore.new
    first_key = Components::Matrix::Table.cache_key_for(
      observations.first, I18n.locale
    )
    # Pre-warm only the first object's fragment -- proves a genuine
    # mix of hit + miss both resolve correctly in one batched pass,
    # not just an all-hit or all-miss case.
    real_store.write(first_key, ["<li>already cached</li>", {}])
    spy = CountingCacheStore.new(real_store)

    component = Components::Matrix::Table.new(
      objects: observations, user: @user, cached: true
    )

    # Phlex-rails' low_level_cache gates on perform_caching (unset,
    # so falsy, in the test env by default) -- without this, it always
    # `yield`s and never touches cache_store at all.
    original_cache = Rails.cache
    original_perform_caching =
      Rails.application.config.action_controller.perform_caching
    html = begin
             Rails.cache = spy
             Rails.application.config.action_controller.perform_caching = true
             render(component)
           ensure
             # Must run even if render raises, or a broken spy cache store
             # leaks into every other test in this worker process.
             Rails.cache = original_cache
             Rails.application.config.action_controller.perform_caching =
               original_perform_caching
           end

    assert_equal(1, spy.read_multi_calls,
                 "expected one batched read regardless of object count")
    assert_equal(1, spy.write_multi_calls,
                 "expected one batched write regardless of miss count")

    assert_includes(html, "already cached",
                    "first object should be served from the prefetched " \
                    "hit, not recomputed")
    assert_not_includes(html, "box_#{observations.first.id}")
    assert_includes(html, "box_#{observations.second.id}",
                    "second object was a genuine miss and must render")

    second_key = Components::Matrix::Table.cache_key_for(
      observations.second, I18n.locale
    )
    cached_buffer, = real_store.read(second_key)
    assert_includes(cached_buffer, "box_#{observations.second.id}",
                    "the miss must be written to the store")
  end

  def test_batched_store_is_cleared_after_render_completes
    obs = observations(:coprinus_comatus_obs)
    obs.thumb_image.update_column(:transferred, true)
    component = Components::Matrix::Table.new(
      objects: [obs], user: @user, cached: true
    )

    original_perform_caching =
      Rails.application.config.action_controller.perform_caching
    begin
      Rails.application.config.action_controller.perform_caching = true
      render(component)
    ensure
      Rails.application.config.action_controller.perform_caching =
        original_perform_caching
    end

    assert_nil(
      component.instance_variable_get(:@batched_store),
      "a stale batched wrapper must not survive past its own render, " \
      "or a later #cache_store call would incorrectly reuse it"
    )
  end
end
