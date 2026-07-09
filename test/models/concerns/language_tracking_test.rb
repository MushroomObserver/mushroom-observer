# frozen_string_literal: true

require("test_helper")

class LanguageTrackingTest < UnitTestCase
  # Tracking is intentionally sticky (no automatic per-request reset -
  # see ApplicationController#track_translations), so another test
  # running earlier in this same worker process may have left it on.
  def setup
    super
    Language.ignore_usage
  end

  def teardown
    Language.ignore_usage
    super
  end

  def test_track_usage_and_note_usage_of_tag
    assert_not(Language.tracking_usage?)

    Language.track_usage
    assert(Language.tracking_usage?)
    assert_equal([], Language.tags_used)

    Language.note_usage_of_tag(:app_title)
    assert_equal(["app_title"], Language.tags_used)
  end

  def test_ignore_usage
    Language.track_usage
    Language.note_usage_of_tag(:app_title)
    Language.ignore_usage
    assert_not(Language.tracking_usage?)
  end

  def test_note_usage_of_tag_without_tracking_is_a_noop
    Language.note_usage_of_tag(:app_title)
    assert_not(Language.tracking_usage?)
  end

  # Proves `tags_used` is thread-local: N threads each turn on
  # tracking, note a *different* tag, then read back `tags_used`,
  # asserting each thread only ever sees its own tag - not another
  # thread's. Before the Thread.current[...] conversion, tags_used was
  # a bare class variable shared by every thread, so concurrent
  # requests would corrupt each other's tracked-tag lists.
  def test_thread_isolation_of_tags_used
    tags = (0...8).map { |i| :"stress_test_tag_#{i}" }
    barrier = Concurrent::CyclicBarrier.new(tags.size)
    results = Queue.new

    threads = tags.map do |tag|
      Thread.new do
        Language.track_usage
        Language.note_usage_of_tag(tag)
        barrier.wait
        results << [tag, Language.tags_used]
      ensure
        Language.ignore_usage
      end
    end
    threads.each(&:join)

    until results.empty?
      tag, observed = results.pop
      assert_equal([tag.to_s], observed,
                   "Thread saw another thread's tags_used " \
                   "(expected only #{tag.inspect}, got #{observed.inspect}) " \
                   "- tags_used is not thread-isolated")
    end
  end
end
