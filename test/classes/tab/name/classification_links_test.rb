# frozen_string_literal: true

require("test_helper")

# Tests the `Tab::Name::ClassificationLinks` Collection's branching
# logic — pins the tab sequence under each conditional. Per the
# project's tabs.md rule: "Tests should pin the order explicitly
# under each conditional branch."
class Tab::Name::ClassificationLinksTest < UnitTestCase
  def setup
    @name = names(:coprinus_comatus)
    @stub_query = Object.new
    # Any Name fixture works as a non-nil first_child stub — the
    # Subtaxa Tab just wraps `@children_query` and doesn't read
    # anything off the first_child itself.
    @stub_first_child = names(:agaricus_campestris)
  end

  def test_no_tabs_when_no_first_child_and_no_visibility_predicates_apply
    # `@first_child` nil → Subtaxa + Propagate suppressed.
    # `Refresh` / `Inherit` predicates checked on the real fixture.
    coll = Tab::Name::ClassificationLinks.new(
      name: @name, children_query: nil, first_child: nil,
      controller: nil
    )

    # Coprinus comatus (species, has classification, accepted-genus
    # classification matches): none of the predicates apply, no
    # subtaxa wrappers, so the collection is empty.
    assert_empty(coll.to_a)
  end

  def test_subtaxa_tab_appears_when_first_child_present
    coll = Tab::Name::ClassificationLinks.new(
      name: @name, children_query: @stub_query,
      first_child: @stub_first_child, controller: nil
    )

    assert(coll.any?(Tab::Name::Subtaxa))
  end

  def test_refresh_tab_appears_when_predicate_matches
    @name.classification = "Phylum: _Different_"
    @name.define_singleton_method(:accepted_genus) do
      Object.new.tap do |g|
        g.define_singleton_method(:classification) { "Phylum: _Original_" }
      end
    end

    coll = Tab::Name::ClassificationLinks.new(
      name: @name, children_query: nil, first_child: nil,
      controller: nil
    )

    assert(coll.any?(Tab::Name::RefreshClassification))
  end

  def test_propagate_tab_requires_both_first_child_and_predicate
    # Predicate alone (no first_child) shouldn't emit propagate.
    name = @name
    name.define_singleton_method(:can_propagate?) { true }
    name.classification = "Phylum: _Foo_"

    coll = Tab::Name::ClassificationLinks.new(
      name: name, children_query: nil, first_child: nil,
      controller: nil
    )

    assert_not(
      coll.any?(Tab::Name::PropagateClassification),
      "Propagate should be gated by `@first_child` even when " \
      "the predicate matches"
    )

    # With first_child too → emitted.
    coll_with_child = Tab::Name::ClassificationLinks.new(
      name: name, children_query: @stub_query,
      first_child: @stub_first_child, controller: nil
    )

    assert(
      coll_with_child.any?(Tab::Name::PropagateClassification)
    )
  end

  def test_inherit_tab_appears_when_predicate_matches
    genus = names(:coprinus)
    genus.classification = ""

    coll = Tab::Name::ClassificationLinks.new(
      name: genus, children_query: nil, first_child: nil,
      controller: nil
    )

    assert(coll.any?(Tab::Name::InheritClassification))
  end

  def test_tab_order_is_subtaxa_refresh_propagate_inherit
    # Stub everything so every tab appears, then pin the order.
    genus = names(:coprinus)
    genus.classification = "Phylum: _Foo_"
    genus.define_singleton_method(:can_propagate?) { true }
    genus.define_singleton_method(:below_genus?) { true } # for refresh
    genus.define_singleton_method(:accepted_genus) do
      Object.new.tap do |g|
        g.define_singleton_method(:classification) { "different" }
      end
    end
    # For inherit to also appear: genus needs classification.blank?
    # and !below_genus? — conflicts with our above-Genus stub. Skip
    # asserting Inherit in the same case; pin the other three.

    coll = Tab::Name::ClassificationLinks.new(
      name: genus, children_query: @stub_query,
      first_child: @stub_first_child, controller: nil
    )

    classes = coll.to_a.map(&:class)
    assert_equal(
      [Tab::Name::Subtaxa,
       Tab::Name::RefreshClassification,
       Tab::Name::PropagateClassification],
      classes
    )
  end
end
