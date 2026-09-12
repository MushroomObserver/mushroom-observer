# frozen_string_literal: true

require("test_helper")

# Proves the actual bug this design fixes (#4807): with the old Simple/
# file backend, a live translation edit only updated the EDITING Puma
# worker's own in-memory hash -- the other 2 forked workers kept serving
# stale text until they restarted. Two independently-constructed backend
# instances here (sharing no object/state with each other) must see each
# other's writes purely through the shared Solid Cache DB table.
#
# What this does NOT prove: real fork-level isolation. Both instances
# run in the same process on the same AR connection here -- this rules
# out a hidden in-Ruby-memory cache, not a fork-specific connection
# issue (see test/test_helper.rb's parallelize_setup and config/puma.rb's
# on_worker_boot for the actual fork-safety fix, which this test doesn't
# independently exercise).
class CrossProcessTranslationVisibilityTest < UnitTestCase
  def setup
    super
    @tag = :"_cross_process_test_tag_#{object_id}"
    @worker_a = build_cache_backend
    @worker_b = build_cache_backend
  end

  def teardown
    @worker_a.delete_translation(:en, @tag)
    super
  end

  def test_write_via_one_worker_is_visible_via_another
    assert_nil(@worker_b.send(:lookup, :en, "mo.#{@tag}"),
               "Sanity check: nothing cached yet")

    @worker_a.store_translations(:en, { mo: { @tag => "hello from worker A" } })

    assert_equal("hello from worker A",
                 @worker_b.send(:lookup, :en, "mo.#{@tag}"),
                 "worker_b shares no Ruby-process memory with worker_a -- " \
                 "only a DB-backed cache store makes this visible")
  end

  private

  def build_cache_backend
    I18n::Backend::SolidCacheKeyValue.new(
      I18n::Backend::CacheStoreAdapter.new(SolidCache::Store.new), false
    )
  end
end
