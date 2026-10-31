# frozen_string_literal: true

require("test_helper")

class Inat::NameStringTest < UnitTestCase
  # The slips found in iNat's "Provisional Species Name" field (#2892).
  def test_clean_repairs_typing_slips
    {
      "Inocybe sp. ' NY17'" => "Inocybe sp. 'NY17'",
      "Hohenbuehelia sp.' TAC491'" => "Hohenbuehelia sp. 'TAC491'",
      "Russula sp. 'IN112 '" => "Russula sp. 'IN112'",
      "Russula sp. 'laurocerasi-IN02" => "Russula sp. 'laurocerasi-IN02'",
      "Cortinarius sp. 'NY26''" => "Cortinarius sp. 'NY26'",
      "  Russula sp. 'IN112'  " => "Russula sp. 'IN112'",
      "Albatrellopsis sp. ‘MD16" => "Albatrellopsis sp. ‘MD16’"
    }.each do |raw, expected|
      assert_equal(expected, Inat::NameString.clean(raw), raw.inspect)
    end
  end

  def test_clean_leaves_well_formed_names_alone
    ["Amanita muscaria", "Russula \"sp-IN112\"",
     "Cystolepiota sp. 'purple and cream'", "Boletus D'Aguilar",
     # sp. inside the quotes changes the name's shape: not a slip.
     "Amanita \"sp. breckonii-CA01\""].each do |name|
      assert_equal(name, Inat::NameString.clean(name), name.inspect)
    end
  end

  def test_clean_rejects_what_no_name_can_express
    assert_nil(Inat::NameString.clean("Inocybe sp. 'CA25 × CA65'"),
               "a hybrid of two provisionals")
    assert_nil(Inat::NameString.clean("  "))
    assert_nil(Inat::NameString.clean(nil))
  end

  def test_parse_parses_the_repaired_string
    parsed = Inat::NameString.parse("Inocybe sp. ' NY17'")

    assert_equal("Inocybe sp. 'NY17'", parsed.search_name)
    assert_nil(Inat::NameString.parse("Inocybe sp. 'CA25 × CA65'"))
  end

  def test_parse_takes_an_infraspecific_rank_from_the_inat_taxon
    { "variety" => "var.", "subspecies" => "subsp.", "form" => "f." }.
      each do |rank, abbreviation|
      taxon = { name: "Mycena epipterygia lignicola", rank: rank }
      assert_equal(
        "Mycena epipterygia #{abbreviation} lignicola",
        Inat::NameString.parse("Mycena epipterygia lignicola",
                               taxon: taxon).search_name,
        "rank #{rank}"
      )
    end

    variety = { name: "Mycena epipterygia lignicola", rank: "variety" }
    assert_nil(Inat::NameString.parse("Mycena epipterygia lignicola"),
               "no rank to take without the taxon")
    assert_nil(Inat::NameString.parse("Mycena epipterygia viscosa",
                                      taxon: variety),
               "the taxon's rank applies only to the taxon's name")
  end
end
