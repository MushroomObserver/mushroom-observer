# frozen_string_literal: true

require("test_helper")

# `.for(...)` returns nil when the inputs make a related-query
# impossible — those branches don't reach into the controller for
# URL building, so they can be tested without a real request
# context. The success branches (Tab::Base behavior + URL
# construction inside `Tab::RelatedQuery#path`) need
# `controller.add_q_param`, which in turn needs a live request —
# those are exercised via downstream caller tests that already
# have a controller context, not here.
class Tab::RelatedQueryTest < UnitTestCase
  def test_for_returns_nil_when_no_current_query
    assert_nil(Tab::RelatedQuery.for(
                 model: Image, filter: :Observation,
                 current_query: nil, controller: nil
               ))
  end

  def test_for_returns_nil_when_no_bridge
    query = ::Query.lookup(:Observation)
    stub_no_bridge = ->(*) { false }

    ::Query.stub(:related?, stub_no_bridge) do
      assert_nil(Tab::RelatedQuery.for(
                   model: Image, filter: :Observation,
                   current_query: query, controller: nil
                 ))
    end
  end

  def test_for_returns_tab_when_bridge_exists
    query = ::Query.lookup(:Observation)
    stub_bridge_ok = ->(*) { true }

    ::Query.stub(:related?, stub_bridge_ok) do
      tab = Tab::RelatedQuery.for(
        model: Image, filter: :Observation,
        current_query: query, controller: nil
      )

      assert_not_nil(tab)
      assert_kind_of(Tab::RelatedQuery, tab)
    end
  end
end
