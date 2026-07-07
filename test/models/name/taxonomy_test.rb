# frozen_string_literal: true

require("test_helper")

# Tests for Name::Taxonomy (app/models/name/taxonomy.rb)
class Name::TaxonomyTest < UnitTestCase
  def create_test_name(string, force_rank = nil)
    parse = Name.parse_name(string)
    assert(parse, "Expected this to parse: #{string}")
    params = parse.params
    params[:rank] = force_rank if force_rank
    params[:user] = rolf
    name = Name.new_name(params)

    # If there's already a name with this search_name, update and use it.
    indistinct_names = Name.where(search_name: name.search_name)
    if indistinct_names.any?
      indistinct_name = indistinct_names.first
      assert(indistinct_name.update(params),
             "Error updating name \"#{string}\": [#{name.dump_errors}]")
      indistinct_name
    else

      assert(name.save,
             "Error saving name \"#{string}\": [#{name.dump_errors}]")
      name
    end
  end

  def do_parse_classification_test(text, expected)
    parse = Name.parse_classification(text)
    assert_equal(expected, parse)
  rescue RuntimeError => e
    raise(e) if expected
  end

  def do_validate_classification_test(rank, text, expected)
    result = Name.validate_classification(rank, text)
    assert_equal_even_if_nil(expected, result)
  rescue RuntimeError => e
    raise(e) if expected
  end

  # -----------------------------
  #  Test classification.
  # -----------------------------

  def test_parse_classification_1
    do_parse_classification_test("Kingdom: Fungi", [%w[Kingdom Fungi]])
  end

  def test_parse_classification_2
    do_parse_classification_test(%(Kingdom: Fungi\r
      Phylum: Basidiomycota\r
      Class: Basidiomycetes\r
      Order: Agaricales\r
      Family: Amanitaceae),
                                 [%w[Kingdom Fungi],
                                  %w[Phylum Basidiomycota],
                                  %w[Class Basidiomycetes],
                                  %w[Order Agaricales],
                                  %w[Family Amanitaceae]])
  end

  def test_parse_classification_3
    do_parse_classification_test(%(Kingdom: Fungi\r
      \r
      Family: Amanitaceae),
                                 [%w[Kingdom Fungi],
                                  %w[Family Amanitaceae]])
  end

  def test_parse_classification_4
    do_parse_classification_test(%(Kingdom: _Fungi_\r
      Family: _Amanitaceae_),
                                 [%w[Kingdom Fungi],
                                  %w[Family Amanitaceae]])
  end

  def test_parse_classification_5
    do_parse_classification_test("Queendom: Fungi", [%w[Queendom Fungi]])
  end

  def test_parse_classification_6
    do_parse_classification_test("Junk text", false)
  end

  def test_parse_classification_7
    do_parse_classification_test(%(Kingdom: Fungi\r
      Junk text\r
      Genus: Amanita), false)
  end

  def test_validate_classification_1
    do_validate_classification_test(
      "Species", "Kingdom: Fungi", "Kingdom: _Fungi_"
    )
  end

  def test_validate_classification_2
    do_validate_classification_test(
      "Species",
      %(Kingdom: Fungi\r
        Phylum: Basidiomycota\r
        Class: Basidiomycetes\r
        Order: Agaricales\r
        Family: Amanitaceae),
      "Kingdom: _Fungi_\r\n" \
      "Phylum: _Basidiomycota_\r\n" \
      "Class: _Basidiomycetes_\r\n" \
      "Order: _Agaricales_\r\n" \
      "Family: _Amanitaceae_"
    )
  end

  def test_validate_classification_3
    do_validate_classification_test("Species", %(Kingdom: Fungi\r
      \r
      Family: Amanitaceae),
                                    "Kingdom: _Fungi_\r\nFamily: _Amanitaceae_")
  end

  def test_validate_classification_4
    do_validate_classification_test("Species", %(Kingdom: _Fungi_\r
      Family: _Amanitaceae_),
                                    "Kingdom: _Fungi_\r\nFamily: _Amanitaceae_")
  end

  def test_validate_classification_5
    do_validate_classification_test("Species", "Queendom: Fungi", false)
  end

  def test_validate_classification_6
    do_validate_classification_test("Species", "Junk text", false)
  end

  def test_validate_classification_7
    do_validate_classification_test("Genus", "Species: calyptroderma", false)
  end

  def test_validate_classification_8
    do_validate_classification_test(
      "Species", "Family: Amanitaceae", "Family: _Amanitaceae_"
    )
  end

  def test_validate_classification_9
    do_validate_classification_test("Queendom", "Family: Amanitaceae", false)
  end

  def test_validate_classification_10
    do_validate_classification_test("Species", "", "")
  end

  def test_validate_classification_11
    do_validate_classification_test("Species", nil, nil)
  end

  def test_validate_classification_12
    do_validate_classification_test("Genus", "Family: _Agaricales_", false)
  end

  def test_validate_classification_13
    do_validate_classification_test("Genus", "Kingdom: _Agaricales_", false)
  end

  def test_validate_classification_14
    do_validate_classification_test(
      "Genus", "Kingdom: _Blubber_", "Kingdom: _Blubber_"
    )
  end

  def test_validate_classification_15
    do_validate_classification_test(
      "Genus", "Kingdom: _Fungi_\nOrder: _Insecta_", false
    )
    do_validate_classification_test(
      "Genus", "Kingdom: _Animalia_\nOrder: _Insecta_",
      "Kingdom: _Animalia_\r\nOrder: _Insecta_"
    )
  end

  def test_validate_classification_raises_on_duplicate_rank
    do_validate_classification_test(
      "Species", "Kingdom: _Fungi_\nKingdom: _Fungi_", false
    )
  end

  def test_validate_classification_normalizes_division_to_phylum
    # Division is a historical synonym for Phylum in some nomenclature systems
    do_validate_classification_test(
      "Species",
      "Kingdom: _Fungi_\nDivision: _Basidiomycota_",
      "Kingdom: _Fungi_\r\nPhylum: _Basidiomycota_"
    )
  end

  def test_validate_classification_defaults_to_own_classification
    name = names(:agaricus_campestris)
    result = name.validate_classification
    assert_equal(
      name.classification, result,
      "validate_classification with no arg should use own classification"
    )
  end

  def test_rank_translated_returns_localized_string
    name = names(:agaricus_campestris)
    assert_equal(:rank_species.l, name.rank_translated,
                 "rank_translated should return localized rank name")
  end

  def test_rank_lists_include_intermediate_ranks
    assert_includes(Name.ranks_above_species, "Series",
                    "Series should be a rank above species")
    assert_includes(Name.ranks_above_species, "Group",
                    "Group should be a rank above species")
    assert_includes(Name.ranks_below_genus, "Series",
                    "Series should be a rank below genus")
    assert_includes(Name.ranks_between_kingdom_and_genus, "Subfamily",
                    "Subfamily should be a rank between kingdom and genus")
  end

  def test_rank_matchers
    name = names(:fungi)
    assert_not(name.at_or_below_genus?)
    assert_not(name.below_genus?)
    assert_not(name.between_genus_and_species?)
    assert_not(name.at_or_below_species?)

    name = names(:agaricus)
    assert(name.at_or_below_genus?)
    assert_not(name.below_genus?)
    assert_not(name.between_genus_and_species?)
    assert_not(name.at_or_below_species?)

    name = names(:amanita_subgenus_lepidella)
    assert(name.at_or_below_genus?)
    assert(name.below_genus?)
    assert(name.between_genus_and_species?)
    assert_not(name.at_or_below_species?)

    name = names(:coprinus_comatus)
    assert(name.at_or_below_genus?)
    assert(name.below_genus?)
    assert_not(name.between_genus_and_species?)
    assert(name.at_or_below_species?)

    name = names(:amanita_boudieri_var_beillei)
    assert(name.at_or_below_genus?)
    assert(name.below_genus?)
    assert_not(name.between_genus_and_species?)
    assert(name.at_or_below_species?)
  end

  def test_genus_display_ranks
    ranks = Name.genus_display_ranks
    Name.ranks.each do |rank_name, rank_val|
      if rank_val.between?(Name.ranks[:Stirps], Name.ranks[:Genus])
        assert_includes(ranks, rank_val,
                        "genus_display_ranks should include #{rank_name}")
      end
    end
    assert_not_includes(ranks, Name.ranks[:Species],
                        "genus_display_ranks should not include Species")
    assert_not_includes(ranks, Name.ranks[:Group],
                        "genus_display_ranks should not include Group")
    assert_not_includes(ranks, Name.ranks[:Family],
                        "genus_display_ranks should not include Family")
  end

  # ------------------------------
  #  Test ancestors and parents.
  # ------------------------------

  def test_ancestors_1
    assert_name_arrays_equal([names(:agaricus),
                              names(:agaricaceae),
                              names(:agaricales),
                              names(:basidiomycetes),
                              names(:basidiomycota),
                              names(:fungi)],
                             names(:agaricus_campestris).all_parents)
    assert_name_arrays_equal(
      [names(:agaricus)], names(:agaricus_campestris).parents
    )
    assert_name_arrays_equal(
      [names(:agaricaceae)], names(:agaricus).parents
    )
    assert_name_arrays_equal(
      [], names(:agaricus_campestris).children
    )
    assert_name_arrays_equal([names(:sect_agaricus)],
                             names(:agaricus).children(all: false), :sort)
    assert_name_arrays_equal([names(:sect_agaricus),
                              names(:agaricus_campestras),
                              names(:agaricus_campestris),
                              names(:agaricus_campestros),
                              names(:agaricus_campestrus)],
                             names(:agaricus).children(all: true), :sort)
  end

  def test_ancestors_2
    # Need a deprecated genus with NO classification string to exercise
    # the fallback path in all_parents / children. Petigera used to
    # serve this purpose, but it now carries a classification (see
    # #4154), so we synthesize an equivalent fixture here.
    pet = create_test_name("Petigera")
    pet.update!(deprecated: true, classification: nil,
                correct_spelling: names(:peltigera),
                synonym_id: names(:peltigera).synonym_id)
    assert_name_arrays_equal([], pet.all_parents)
    assert_name_arrays_equal([], pet.children)

    # rubocop:disable Layout/LineLength
    # disable cop for comparative readability
    pc =   create_test_name("Petigera canina (L.) Willd.")
    pcr =  create_test_name("Petigera canina var. rufescens (Weiss) Mudd")
    pcri = create_test_name("Petigera canina var. rufescens f. innovans (Körber) J. W. Thomson")
    pcs  = create_test_name("Petigera canina var. spuria (Ach.) Schaerer")

    pa   = create_test_name("Petigera aphthosa (L.) Willd.")
    pac  = create_test_name("Petigera aphthosa f. complicata (Th. Fr.) Zahlbr.")
    pav  = create_test_name("Petigera aphthosa var. variolosa A. Massal.")

    pp   = create_test_name("Petigera polydactylon (Necker) Hoffm")
    pp2  = create_test_name("Petigera polydactylon (Bogus) Author")
    pph  = create_test_name("Petigera polydactylon var. hymenina (Ach.) Flotow")
    ppn  = create_test_name("Petigera polydactylon var. neopolydactyla Gyelnik")
    # rubocop:enable Layout/LineLength

    assert_name_arrays_equal([pa, pc, pp, pp2], pet.children, :sort)
    assert_name_arrays_equal([pcr, pcs], pc.children, :sort)
    assert_name_arrays_equal([pcri], pcr.children, :sort)
    assert_name_arrays_equal([pav], pa.children, :sort)
    assert_name_arrays_equal([pph, ppn], pp.children, :sort)

    # Oops! Petigera is misspelled, so these aren't right...
    assert_name_arrays_equal([], pc.all_parents)
    assert_name_arrays_equal([pc], pcr.all_parents)
    assert_name_arrays_equal([pcr, pc], pcri.all_parents)
    assert_name_arrays_equal([pc], pcs.all_parents)
    assert_name_arrays_equal([], pa.all_parents)
    assert_name_arrays_equal([pa], pac.all_parents)
    assert_name_arrays_equal([pa], pav.all_parents)
    assert_name_arrays_equal([], pp.all_parents)
    assert_name_arrays_equal([], pp2.all_parents)
    assert_name_arrays_equal([pp], pph.all_parents)
    assert_name_arrays_equal([pp], ppn.all_parents)

    assert_name_arrays_equal([], pc.parents)
    assert_name_arrays_equal([pc], pcr.parents)
    assert_name_arrays_equal([pcr], pcri.parents)
    assert_name_arrays_equal([pc], pcs.parents)
    assert_name_arrays_equal([], pa.parents)
    assert_name_arrays_equal([pa], pac.parents)
    assert_name_arrays_equal([pa], pav.parents)
    assert_name_arrays_equal([], pp.parents)
    assert_name_arrays_equal([pp], pph.parents)
    assert_name_arrays_equal([pp], ppn.parents)

    # Try it again if we clear the misspelling flag.  (Still deprecated though.)
    pet.correct_spelling = nil
    pet.save

    assert_name_arrays_equal([pet], pc.all_parents, :sort)
    assert_name_arrays_equal([pc], pcr.all_parents, :sort)
    assert_name_arrays_equal([pcr, pc], pcri.all_parents, :sort)
    assert_name_arrays_equal([pc], pcs.all_parents, :sort)
    assert_name_arrays_equal([pet], pa.all_parents, :sort)
    assert_name_arrays_equal([pa], pac.all_parents, :sort)
    assert_name_arrays_equal([pa], pav.all_parents, :sort)
    assert_name_arrays_equal([pet], pp.all_parents, :sort)
    assert_name_arrays_equal([pet], pp2.all_parents, :sort)
    assert_name_arrays_equal([pp], pph.all_parents, :sort)
    assert_name_arrays_equal([pp], ppn.all_parents, :sort)

    assert_name_arrays_equal([pet], pc.parents)
    assert_name_arrays_equal([pc], pcr.parents)
    assert_name_arrays_equal([pcr], pcri.parents)
    assert_name_arrays_equal([pc], pcs.parents)
    assert_name_arrays_equal([pet], pa.parents)
    assert_name_arrays_equal([pa], pac.parents)
    assert_name_arrays_equal([pa], pav.parents)
    assert_name_arrays_equal([pet], pp.parents)
    assert_name_arrays_equal([pp], pph.parents, :sort)
    assert_name_arrays_equal([pp], ppn.parents, :sort)

    pp2.change_deprecated(true)
    pp2.save

    assert_name_arrays_equal([pa, pc, pp, pp2], pet.children, :sort)
    assert_name_arrays_equal([pp], pph.all_parents, :sort)
    assert_name_arrays_equal([pp], ppn.all_parents, :sort)
    assert_name_arrays_equal([pp], pph.parents, :sort)
    assert_name_arrays_equal([pp], ppn.parents, :sort)

    pp.change_deprecated(true)
    pp.save

    assert_name_arrays_equal([pa, pc, pp, pp2], pet.children, :sort)
    assert_name_arrays_equal([pp, pet], pph.all_parents, :sort)
    assert_name_arrays_equal([pp, pet], ppn.all_parents, :sort)
    assert_name_arrays_equal([pp], pph.parents, :sort)
    assert_name_arrays_equal([pp], ppn.parents, :sort)
  end

  def test_ancestors_3
    # Names with Ascomycota in classification OR search_name starting with it.
    # Includes: Ascomycota itself + Ascomycetes through Peltigera, plus
    # Petigera (deprecated misspelling of Peltigera, whose fixture now
    # also carries the classification — see #4154).
    assert_equal(6, Name.classification_has("Ascomycota").count)

    kng = names(:fungi)
    phy = names(:ascomycota)
    cls = names(:ascomycetes)
    ord = names(:lecanorales)
    fam = names(:peltigeraceae)
    gen = names(:peltigera)
    spc = create_test_name("Peltigera canina (L.) Willd.")
    ssp = create_test_name("Peltigera canina ssp. bogus (Bugs) Bunny")
    var = create_test_name(
      "Peltigera canina ssp. bogus var. rufescens (Weiss) Mudd"
    )
    frm = create_test_name(
      "Peltigera canina ssp. bogus var. rufescens " \
      "f. innovans (Körber) J. W. Thomson"
    )

    assert_name_arrays_equal([], kng.all_parents)
    assert_name_arrays_equal([kng], phy.all_parents)
    assert_name_arrays_equal([phy, kng], cls.all_parents)
    assert_name_arrays_equal([cls, phy, kng], ord.all_parents)
    assert_name_arrays_equal([ord, cls, phy, kng], fam.all_parents)
    assert_name_arrays_equal([fam, ord, cls, phy, kng], gen.all_parents)
    assert_name_arrays_equal([gen, fam, ord, cls, phy, kng], spc.all_parents)
    assert_name_arrays_equal([spc, gen, fam, ord, cls, phy, kng],
                             ssp.all_parents)
    assert_name_arrays_equal([ssp, spc, gen, fam, ord, cls, phy, kng],
                             var.all_parents)
    assert_name_arrays_equal([var, ssp, spc, gen, fam, ord, cls, phy, kng],
                             frm.all_parents)

    assert_name_arrays_equal([],    kng.parents)
    assert_name_arrays_equal([kng], phy.parents)
    assert_name_arrays_equal([phy], cls.parents)
    assert_name_arrays_equal([cls], ord.parents)
    assert_name_arrays_equal([ord], fam.parents)
    assert_name_arrays_equal([fam], gen.parents)
    assert_name_arrays_equal([gen], spc.parents)
    assert_name_arrays_equal([spc], ssp.parents)
    assert_name_arrays_equal([ssp], var.parents)
    assert_name_arrays_equal([var], frm.parents)

    assert(kng.children.include?(phy))
    assert_name_arrays_equal([cls], phy.children)
    assert_name_arrays_equal([ord], cls.children)
    assert_name_arrays_equal([fam], ord.children)
    assert_name_arrays_equal([gen], fam.children)
    assert_name_arrays_equal([spc], gen.children)
    assert_name_arrays_equal([ssp], spc.children)
    assert_name_arrays_equal([var], ssp.children)
    assert_name_arrays_equal([frm], var.children)
    assert_name_arrays_equal([],    frm.children)

    assert_empty([phy, cls, ord, fam, gen, spc, ssp, var, frm] -
                 kng.all_children)
    assert_name_arrays_equal([cls, ord, fam, gen, spc, ssp, var, frm],
                             phy.all_children, :sort)
    assert_name_arrays_equal([ord, fam, gen, spc, ssp, var, frm],
                             cls.all_children, :sort)
    assert_name_arrays_equal([fam, gen, spc, ssp, var, frm],
                             ord.all_children, :sort)
    assert_name_arrays_equal([gen, spc, ssp, var, frm], fam.all_children, :sort)
    assert_name_arrays_equal([spc, ssp, var, frm], gen.all_children, :sort)
    assert_name_arrays_equal([ssp, var, frm], spc.all_children, :sort)
    assert_name_arrays_equal([var, frm], ssp.all_children, :sort)
    assert_name_arrays_equal([frm], var.all_children, :sort)
    assert_name_arrays_equal([], frm.all_children, :sort)
  end

  def test_has_eol_data
    assert(names(:peltigera).has_eol_data?,
           "peltigera should have EoL data via qualifying observation image")
    assert_not(names(:lactarius_alpigenes).has_eol_data?,
               "lactarius_alpigenes is deprecated so has no EoL data")
  end

  def test_has_eol_data_true_via_vetted_description
    name = names(:peltigera)
    # peltigera returns true via observations normally; disqualify them
    # so the descriptions loop is exercised instead
    name.observations.update_all(vote_cache: 0)
    assert(
      name.has_eol_data?,
      "`eol_data?` should be true via vetted description " \
      "when no observation qualifies"
    )
  end
end
