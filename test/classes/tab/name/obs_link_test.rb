# frozen_string_literal: true

require("test_helper")

# Contract tests for the `Tab::Name::ObsLink::*` family. Each Tab
# encapsulates a label, a `Query::Observations` filter attr, and a
# count. The view uses `#linked?` to decide whether to render an
# `<a>` (count > 0) or a plain "(0)" placeholder.
class Tab::Name::ObsLinkTest < UnitTestCase
  def routes
    Rails.application.routes.url_helpers
  end

  def setup
    @name = names(:coprinus_comatus)
  end

  # --- Title and linked? ----------------------------------------

  def test_title_includes_label_and_count
    tab = build_tab(Tab::Name::ObsLink::ThisName, count: 5)

    assert_equal("#{:obss_of_this_name.t} (5)", tab.title)
  end

  def test_linked_when_count_positive
    tab = build_tab(Tab::Name::ObsLink::ThisName, count: 1)

    assert(tab.linked?)
  end

  def test_not_linked_when_count_zero
    tab = build_tab(Tab::Name::ObsLink::ThisName, count: 0)

    assert_not(tab.linked?)
  end

  # --- alt_title is stable across counts ------------------------

  def test_alt_title_is_label_key_string
    tab = build_tab(Tab::Name::ObsLink::OtherNames, count: 3)

    # Pin to the label key — selector class derivation uses
    # alt_title, so the rendered class stays the same when the
    # count moves.
    assert_equal("taxon_obss_other_names", tab.alt_title)
  end

  # --- Path per subclass ------------------------------------------

  # Each subclass's flag combination (synonyms, exclude_consensus,
  # etc.) lives in the same-named Query::Observations attr, not
  # here -- see obs_link_query_integration_test.rb for the
  # results-based coverage of that behavior. These just pin which
  # attr each subclass's path wires up.
  def test_this_name_path
    tab = build_tab(Tab::Name::ObsLink::ThisName, count: 1)

    assert_equal(routes.observations_path(this_name: @name.id), tab.path)
  end

  def test_other_names_path
    tab = build_tab(Tab::Name::ObsLink::OtherNames, count: 1)

    assert_equal(routes.observations_path(other_names: @name.id), tab.path)
  end

  def test_any_name_path
    tab = build_tab(Tab::Name::ObsLink::AnyName, count: 1)

    assert_equal(routes.observations_path(any_name: @name.id), tab.path)
  end

  def test_taxon_proposed_path
    tab = build_tab(Tab::Name::ObsLink::TaxonProposed, count: 1)

    assert_equal(routes.observations_path(look_alikes: @name.id), tab.path)
  end

  def test_name_proposed_path
    tab = build_tab(Tab::Name::ObsLink::NameProposed, count: 1)

    assert_equal(routes.observations_path(name_proposed: @name.id), tab.path)
  end

  # --- Subtaxa wraps a controller-provided query ---------------

  def test_subtaxa_uses_injected_query
    inj = Query.lookup_and_save(:Observation, pattern: "stub")
    tab = Tab::Name::ObsLink::Subtaxa.new(
      name: @name, count: 7, controller: nil, query: inj
    )

    assert_same(inj, tab.query)
    assert_equal("#{:show_subtaxa_obss.t} (7)", tab.title)
  end

  private

  def build_tab(klass, count:)
    klass.new(name: @name, count: count)
  end
end
