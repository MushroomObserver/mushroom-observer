# frozen_string_literal: true

require("test_helper")

# Tests the `Tab::QueryLink` abstract base by spinning up a stub
# subclass — verifies memoization of `#query` (so subclasses with
# save side-effects don't double-save) and that `#path` calls
# through to `controller.add_q_param(target_params, query)`.
class Tab::QueryLinkTest < UnitTestCase
  class StubTab < Tab::QueryLink
    def title = "stub"
    def alt_title = "stub"

    private

    def build_query
      @build_calls ||= 0
      @build_calls += 1
      ::Query.lookup_and_save(:Observation)
    end

    def target_params
      { controller: "/observations", action: :index }
    end

    public

    attr_reader :build_calls
  end

  def test_query_is_memoized
    tab = StubTab.new(controller: stub_controller)

    tab.query
    tab.query
    tab.query

    assert_equal(1, tab.build_calls,
                 "`#build_query` should be called exactly once " \
                 "even when `#query` is read multiple times — the " \
                 "memoization protects subclasses with save " \
                 "side-effects from double-saving")
  end

  def test_path_delegates_to_controller_add_q_param
    controller = stub_controller(echo_path: true)
    tab = StubTab.new(controller: controller)

    result = tab.path

    assert_equal(controller.last_target,
                 { controller: "/observations", action: :index })
    assert_equal(controller.last_query, tab.query)
    assert_equal({ controller: "/observations", action: :index,
                   q: "STUB" }, result)
  end

  def test_subclass_must_implement_build_query_and_target_params
    klass = Class.new(Tab::QueryLink) do
      def title = "x"
    end

    tab = klass.new(controller: stub_controller)

    assert_raises(NotImplementedError) { tab.query }
  end

  private

  def stub_controller(echo_path: false)
    Object.new.tap do |o|
      o.define_singleton_method(:last_target) { @last_target }
      o.define_singleton_method(:last_query)  { @last_query }
      o.define_singleton_method(:add_q_param) do |target, query|
        @last_target = target
        @last_query = query
        if echo_path
          target.merge(q: "STUB")
        else
          target
        end
      end
    end
  end
end
