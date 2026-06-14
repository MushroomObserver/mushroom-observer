# frozen_string_literal: true

require("test_helper")

# Smoke + contract tests for the IpListState value object used
# by `Admin::BlockedIpsController` and `Admin::BlockedIps::Edit` /
# `Manager`. The class is a thin `Data.define` so the tests pin
# what consumers depend on: field accessors, immutability, and
# equality by value.
class Admin::BlockedIps::IpListStateTest < UnitTestCase
  Klass = ::Admin::BlockedIps::IpListState

  def test_keyword_construction_exposes_all_fields
    state = Klass[
      ips: ["1.2.3.4", "5.6.7.8"],
      page: 2, total_pages: 5, total_count: 137,
      starts_with: "1.2."
    ]

    assert_equal(["1.2.3.4", "5.6.7.8"], state.ips)
    assert_equal(2, state.page)
    assert_equal(5, state.total_pages)
    assert_equal(137, state.total_count)
    assert_equal("1.2.", state.starts_with)
  end

  def test_starts_with_can_be_nil
    state = Klass[ips: [], page: 1, total_pages: 1,
                  total_count: 0, starts_with: nil]

    assert_nil(state.starts_with)
  end

  # Value equality — two instances with the same payload are ==.
  # Used in tests + safe for memoization.
  def test_equality_by_value
    a = Klass[ips: ["1.2.3.4"], page: 1, total_pages: 1,
              total_count: 1, starts_with: nil]
    b = Klass[ips: ["1.2.3.4"], page: 1, total_pages: 1,
              total_count: 1, starts_with: nil]

    assert_equal(a, b)
  end

  # `Data` instances are frozen — guards against accidental mutation.
  def test_instances_are_immutable
    state = Klass[ips: [], page: 1, total_pages: 1,
                  total_count: 0, starts_with: nil]

    assert_predicate(state, :frozen?)
  end

  # All five fields are required positional/keyword arguments — the
  # controller computes every field on each request, so a missing one
  # would be a real bug, not a defaulted edge case.
  def test_all_fields_required
    assert_raises(ArgumentError) do
      Klass[ips: [], page: 1, total_pages: 1, total_count: 0]
    end
  end
end
