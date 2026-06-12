# frozen_string_literal: true

require("test_helper")

# Tests the `Tab::Name::ObsLink::All` Collection — the 5 standard
# obs-link tabs always appear (one per row in the menu); the
# Subtaxa tab only appears when `has_subtaxa` is positive.
class Tab::Name::ObsLink::AllTest < UnitTestCase
  def setup
    @name = names(:coprinus_comatus)
  end

  def test_emits_five_standard_tabs_when_no_subtaxa
    coll = Tab::Name::ObsLink::All.new(
      name: @name, obss: stub_obss, controller: nil,
      subtaxa_query: nil, has_subtaxa: 0
    )

    assert_equal(
      [Tab::Name::ObsLink::ThisName,
       Tab::Name::ObsLink::OtherNames,
       Tab::Name::ObsLink::AnyName,
       Tab::Name::ObsLink::TaxonProposed,
       Tab::Name::ObsLink::NameProposed],
      coll.map(&:class)
    )
  end

  def test_appends_subtaxa_tab_when_has_subtaxa_positive
    coll = Tab::Name::ObsLink::All.new(
      name: @name, obss: stub_obss, controller: nil,
      subtaxa_query: stub_query, has_subtaxa: 3
    )

    assert_equal(6, coll.to_a.length)
    assert_kind_of(Tab::Name::ObsLink::Subtaxa, coll.to_a.last)
  end

  def test_omits_subtaxa_tab_when_has_subtaxa_zero
    coll = Tab::Name::ObsLink::All.new(
      name: @name, obss: stub_obss, controller: nil,
      subtaxa_query: stub_query, has_subtaxa: 0
    )

    assert_not(coll.any?(Tab::Name::ObsLink::Subtaxa))
  end

  def test_each_tab_carries_its_count_from_obss
    obss = stub_obss(this_name: 5, other_names: 2, any_name: 7,
                     taxon_proposed: 1, name_proposed: 4)
    coll = Tab::Name::ObsLink::All.new(
      name: @name, obss: obss, controller: nil,
      subtaxa_query: nil, has_subtaxa: 0
    )

    titles = coll.map(&:title)
    assert(titles[0].end_with?("(5)"), "ThisName: #{titles[0]}")
    assert(titles[1].end_with?("(2)"), "OtherNames: #{titles[1]}")
    assert(titles[2].end_with?("(7)"), "AnyName: #{titles[2]}")
    assert(titles[3].end_with?("(1)"), "TaxonProposed: #{titles[3]}")
    assert(titles[4].end_with?("(4)"), "NameProposed: #{titles[4]}")
  end

  private

  # `Name::Observations` PORO — duck-typed via the count methods
  # the Collection iterates over.
  def stub_obss(this_name: 0, other_names: 0, any_name: 0,
                taxon_proposed: 0, name_proposed: 0)
    Object.new.tap do |o|
      {
        of_taxon_this_name: this_name,
        of_taxon_other_names: other_names,
        of_taxon_any_name: any_name,
        where_taxon_proposed: taxon_proposed,
        where_name_proposed: name_proposed
      }.each do |method, count|
        o.define_singleton_method(method) { Array.new(count) }
      end
    end
  end

  def stub_query
    Object.new
  end
end
