# frozen_string_literal: true

require("test_helper")

# Contract tests for the `Tab::Name::ObsLink::*` family. Each Tab
# encapsulates a label, a saved `Query::Observations`, and a
# count. The view uses `#linked?` to decide whether to render an
# `<a>` (count > 0) or a plain "(0)" placeholder.
#
# Path construction (`controller.add_q_param`) is exercised via
# the names-show controller test — that has a live controller; a
# unit test here would stub it out and prove little. We pin the
# title format, the link/no-link predicate, the html_options data
# attrs, and that each subclass's query has the right `names`
# subkeys.
class Tab::Name::ObsLinkTest < UnitTestCase
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

  # --- html_options data attrs ----------------------------------

  def test_html_options_empty_when_not_linked
    tab = build_tab(Tab::Name::ObsLink::ThisName, count: 0)

    # Allow the Tab::Base composer to add a derived selector
    # class, but the data attrs must be absent.
    assert_nil(tab.html_options[:data])
  end

  def test_html_options_carries_filter_caption_data_when_linked
    tab = build_tab(Tab::Name::ObsLink::ThisName, count: 4)

    data = tab.html_options[:data]
    assert_not_nil(data)
    assert(data[:query_params].present?)
    assert(data[:query_record].positive?)
    assert(data[:query_alph].present?)
  end

  # --- Query shape per subclass --------------------------------

  def test_this_name_query_has_lookup_only
    q = build_tab(Tab::Name::ObsLink::ThisName, count: 1).query

    assert_equal({ lookup: [@name.id] }, q.params[:names])
  end

  def test_other_names_query_has_synonyms_and_exclude
    q = build_tab(Tab::Name::ObsLink::OtherNames, count: 1).query

    assert_equal(true, q.params[:names][:include_synonyms])
    assert_equal(true, q.params[:names][:exclude_original_names])
  end

  def test_any_name_query_includes_synonyms_no_exclude
    q = build_tab(Tab::Name::ObsLink::AnyName, count: 1).query

    assert_equal(true, q.params[:names][:include_synonyms])
    assert_nil(q.params[:names][:exclude_original_names])
  end

  def test_taxon_proposed_query_excludes_consensus
    q = build_tab(Tab::Name::ObsLink::TaxonProposed, count: 1).query

    assert_equal(true, q.params[:names][:include_synonyms])
    assert_equal(true, q.params[:names][:include_all_name_proposals])
    assert_equal(true, q.params[:names][:exclude_consensus])
  end

  def test_name_proposed_query_has_all_proposals_no_synonyms
    q = build_tab(Tab::Name::ObsLink::NameProposed, count: 1).query

    assert_equal(true, q.params[:names][:include_all_name_proposals])
    assert_nil(q.params[:names][:include_synonyms])
  end

  # --- Query memoization saves once ----------------------------

  def test_query_save_runs_once
    tab = build_tab(Tab::Name::ObsLink::ThisName, count: 1)

    # First read triggers build + save; second read returns the
    # memoized instance without rebuilding.
    first = tab.query
    second = tab.query

    assert_same(first, second,
                "memoization should return the same instance")
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
    klass.new(name: @name, count: count, controller: nil)
  end
end
