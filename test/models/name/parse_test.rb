# frozen_string_literal: true

require("test_helper")

# Tests for Name::Parse (app/models/name/parse.rb)
class Name::ParseTest < UnitTestCase
  # Parse a string, with detailed error message.
  def do_name_parse_test(str, expects)
    parse = Name.parse_name(str, deprecated: expects[:deprecated])
    assert(parse, "Expected #{str.inspect} to parse!")
    any_errors = false
    msg = ["Name is wrong; expected -vs- actual:"]
    [
      :text_name,
      :real_text_name,
      :search_name,
      :real_search_name,
      :sort_name,
      :display_name,
      :parent_name,
      :rank,
      :author
    ].each do |var|
      expect = expects[var]
      actual = case var
               when :real_text_name
                 Name.display_to_real_text(parse)
                 # parse.display_name.gsub(/\*?\*?__\*?\*?/, "")
               when :real_search_name
                 Name.display_to_real_search(parse)
               else
                 parse.send(var)
               end

      if actual != expect
        any_errors = true
        var = "#{var} (*)"
      end
      msg << format(
        "%-20<var>s %-40<expect>s %-40<actual>s",
        var: var.to_s, expect: expect.inspect, actual: actual.inspect
      )
    end
    assert_not(any_errors, msg.join("\n"))
  end

  def assert_name_match_author_required(pattern, string, first_match = string)
    assert_not(pattern.match(string),
               "Expected #{string.inspect} not to match #{@pat}.")
    assert_name_match_various_authors(pattern, string, first_match)
  end

  def assert_name_match_author_optional(pattern, string, first_match = string)
    assert_name_match(pattern, string, first_match, "")
    assert_name_match_various_authors(pattern, string, first_match)
  end

  def assert_name_match_various_authors(pattern, string, first_match)
    assert_name_match(pattern, "#{string} Author", first_match, " Author")
    assert_name_match(pattern, "#{string} Śliwa", first_match, " Śliwa")
    assert_name_match(pattern, %(#{string} "Author"), first_match, ' "Author"')
    assert_name_match(pattern, %(#{string} "Česka"), first_match, ' "Česka"')
    assert_name_match(pattern, "#{string} (One) Two", first_match, " (One) Two")
    assert_name_match(pattern, "#{string} auct", first_match, " auct")
    assert_name_match(pattern, "#{string} auct non Aurora",
                      first_match, " auct non Aurora")
    assert_name_match(pattern, "#{string} auct Borealis",
                      first_match, " auct Borealis")
    assert_name_match(pattern, "#{string} auct. N. Amer.",
                      first_match, " auct. N. Amer.")
    assert_name_match(pattern, "#{string} ined",
                      first_match, " ined")
    assert_name_match(pattern, "#{string} in ed.", first_match, " in ed.")
    assert_name_match(pattern, "#{string} nomen nudum",
                      first_match, " nomen nudum")
    assert_name_match(pattern, "#{string} nom. prov.",
                      first_match, " nom. prov.")
    assert_name_match(pattern, "#{string} comb. prov.",
                      first_match, " comb. prov.")
    assert_name_match(pattern, "#{string} sensu Author",
                      first_match, " sensu Author")
    assert_name_match(pattern, %(#{string} sens. "Author"),
                      first_match, ' sens. "Author"')
    assert_name_match(pattern, %(#{string} "(One) Two"),
                      first_match, ' "(One) Two"')
  end

  def assert_name_match(pattern, string, first, second = "")
    match = pattern.match(string)
    assert(match, "Expected #{string.inspect} to match #{@pat}.")
    assert_equal(first, match[1].to_s,
                 "#{@pat} matched name part of #{string.inspect} wrong.")
    assert_equal(second, match[2].to_s,
                 "#{@pat} matched author part of #{string.inspect} wrong.")
  end

  def assert_name_parse_fails(str)
    parse = Name.parse_name(str)
    assert_not(
      parse, "Expected #{str.inspect} to fail to parse! Got: #{parse.inspect}"
    )
  end

  def test_standardize_name
    assert_equal("Amanita", Name.standardize_name("Amanita"))
    assert_equal("Amanita subg. Vaginatae",
                 Name.standardize_name("Amanita subgenus Vaginatae"))
    assert_equal("Amanita subg. Vaginatae",
                 Name.standardize_name("Amanita SUBG. Vaginatae"))
    assert_equal("Amanita subg. Vaginatae",
                 Name.standardize_name("Amanita subgen. Vaginatae"))
    assert_equal("Amanita subsect. Vaginatae",
                 Name.standardize_name("Amanita subsect Vaginatae"))
    assert_equal("Amanita stirps Vaginatae",
                 Name.standardize_name("Amanita Stirps Vaginatae"))
    assert_equal(
      "Amanita subg. One sect. Two stirps Three",
      Name.standardize_name("Amanita Subg One Sect Two Stirps Three")
    )
    assert_equal("Amanita vaginata", Name.standardize_name("Amanita vaginata"))
    assert_equal("Amanita vaginata subsp. grisea",
                 Name.standardize_name("Amanita vaginata ssp grisea"))
    assert_equal("Amanita vaginata subsp. grisea",
                 Name.standardize_name("Amanita vaginata s grisea"))
    assert_equal("Amanita vaginata subsp. grisea",
                 Name.standardize_name("Amanita vaginata SUBSP grisea"))
    assert_equal("Amanita vaginata var. grisea",
                 Name.standardize_name("Amanita vaginata V grisea"))
    assert_equal("Amanita vaginata var. grisea",
                 Name.standardize_name("Amanita vaginata var grisea"))
    assert_equal("Amanita vaginata var. grisea",
                 Name.standardize_name("Amanita vaginata Var. grisea"))
    assert_equal("Amanita vaginata f. grisea",
                 Name.standardize_name("Amanita vaginata Forma grisea"))
    assert_equal("Amanita vaginata f. grisea",
                 Name.standardize_name("Amanita vaginata form grisea"))
    assert_equal("Amanita vaginata f. grisea",
                 Name.standardize_name("Amanita vaginata F grisea"))
    assert_equal("Amanita vaginata subsp. one var. two f. three",
                 Name.standardize_name("Amanita vaginata s one v two f three"))
  end

  def test_standardize_author
    assert_equal("auct.", Name.standardize_author("AUCT"))
    assert_equal("auct. N. Amer.", Name.standardize_author("auct. N. Amer."))
    assert_equal("ined. Xxx", Name.standardize_author("IN ED Xxx"))
    assert_equal("ined.", Name.standardize_author("ined."))
    assert_equal("nom. prov.", Name.standardize_author("nom prov"))
    assert_equal("nom. nudum", Name.standardize_author("Nomen nudum"))
    assert_equal("nom.", Name.standardize_author("nomen"))
    assert_equal("comb.", Name.standardize_author("comb"))
    assert_equal("comb. prov.", Name.standardize_author("comb prov"))
    assert_equal("sensu Borealis", Name.standardize_author("SENS Borealis"))
    assert_equal('sensu "Aurora"', Name.standardize_author('sEnSu. "Aurora"'))
  end

  def test_squeeze_author
    assert_equal("A.H. Smith", Name.squeeze_author("A. H. Smith"))
    assert_equal("A.-H. Smith", Name.squeeze_author("A.-H. Smith"))
    assert_equal("AA.H. Sm.", Name.squeeze_author("AA. H. Sm."))
    assert_equal(
      "A.B.C. de Not, Brodo, I., Rowlings, J.K.",
      Name.squeeze_author("A. B. C. de Not, Brodo, I., Rowlings, J.K.")
    )
  end

  def test_upper_word_pats
    pat = /^#{::Name::Parse::UPPER_WORD}$/o
    assert_no_match(pat, "")
    assert_no_match(pat, "A")
    assert_no_match(pat, "A-")
    assert_match(pat, "Ab")
    assert_match(pat, '"Ab"')
    assert_no_match(pat, '"Sp-ABC"')
    assert_no_match(pat, '"S01"')
    assert_match(pat, '"Abc\'')
    assert_match(pat, "'Abc'")
    assert_no_match(pat, '\'"Abc"')
    assert_match(pat, "Abc-def")
    assert_no_match(pat, "Abcdef-")
    assert_no_match(pat, "-Abcdef")
    assert_no_match(pat, "Abc1def")
    assert_no_match(pat, "AbcXdef")
    assert_match(pat, "Abcëdef")
  end

  def test_lower_word_pats
    pat = /^#{::Name::Parse::LOWER_WORD}$/o
    assert_no_match(pat, "")
    assert_no_match(pat, "a")
    assert_no_match(pat, "a-")
    assert_match(pat, "ab")
    assert_match(pat, '"ab"')
    assert_match(pat, '"sp-ABC"')
    assert_match(pat, '"sp-S01"')
    assert_match(pat, '"sp.S01"')
    assert_match(pat, '"sp. S01"')
    assert_match(pat, '"S01"')
    assert_match(pat, '"abc\'')
    assert_match(pat, "'abc'")
    assert_no_match(pat, '\'"abc"')
    assert_match(pat, "abc-def")
    assert_no_match(pat, "abcdef-")
    assert_no_match(pat, "-abcdef")
    assert_no_match(pat, "abc1def")
    assert_no_match(pat, "abcXdef")
    assert_match(pat, "abcëdef")
    assert_no_match(pat, "van")
    assert_no_match(pat, "de")
  end

  def test_author_pat
    @pat = "AUTHOR_PAT"
    pat = ::Name::Parse::AUTHOR_PAT
    assert_no_match(pat, "")
    assert_no_match(pat, "fails")
    assert_no_match(pat, "Amanita spuh.")
    assert_no_match(pat, "Amanita vaginata fails")
    assert_no_match(pat, 'Amanita vaginata "author"')
    assert_no_match(pat, "Amanita sec. Vaginatae")
    assert_no_match(pat, 'Amanita subsect. "Mismatch\'')
    assert_name_match_author_required(pat, "Amanita")
    assert_name_match_author_required(pat, "Amanita sp.")
    assert_name_match_author_required(pat, '"Amanita" sp.')
    assert_name_match_author_required(pat, "Amanita vaginata")
    assert_name_match_author_required(pat, 'Amanita "vaginata"')
    assert_name_match_author_required(pat, "Amanita Subgenus Vaginatae")
    assert_name_match_author_required(pat, "Amanita subg Vaginatae")
    assert_name_match_author_required(pat, 'Amanita subg "Vaginatae"')
    assert_name_match_author_required(
      pat, "Amanita subg Vaginatae subsect Vaginatae stirps Vaginatae"
    )
    assert_name_match_author_required(pat, "Amanita Stirps Vaginatae")
    assert_name_match_author_required(pat, "Amanita vaginata SUBSP grisea")
    assert_name_match_author_required(pat, 'Amanita vaginata ssp. "ssp-S01"')
    assert_name_match_author_required(
      pat, "Amanita vaginata s grisea v negra f alba"
    )
    assert_name_match_author_required(
      pat, "Amanita vaginata ssp grisea var negra form alba"
    )
    assert_name_match_author_required(pat, "Amanita vaginata forma alba")
    assert_no_match(pat, "Amanita vaginata group")
    assert_no_match(pat, "Amanita vaginata v. grisea group")
    assert_no_match(pat, "Amanita vaginata group Author")
    assert_no_match(pat, "Amanita vaginata v. grisea group Author")
    match = pat.match("Lecania van den Boom")
    assert_equal(" van den Boom", match[2])
    match = pat.match("Lecania ryaniana van den Boom")
    assert_equal(" van den Boom", match[2])
    match = pat.match("Lecania de Hoog")
    assert_equal(" de Hoog", match[2])
    match = pat.match("Lecania ryaniana de Hoog")
    assert_equal(" de Hoog", match[2])
  end

  def test_group_pat
    @pat = "GROUP_PAT"
    pat = ::Name::Parse::GROUP_PAT
    assert_name_match(pat, "Amanita group", "Amanita")
    assert_name_match(pat, "Amanita Group", "Amanita")
    assert_name_match(pat, "Amanita Gr", "Amanita")
    assert_name_match(pat, "Amanita Gp.", "Amanita")
    assert_name_match(pat, "Amanita vaginata group", "Amanita vaginata")
    assert_name_match(pat,
                      "Amanita vaginata ssp. grisea group",
                      "Amanita vaginata ssp. grisea")
    assert_name_match(pat,
                      "Amanita vaginata var. grisea group",
                      "Amanita vaginata var. grisea")
    assert_name_match(pat,
                      "Amanita vaginata f. grisea group",
                      "Amanita vaginata f. grisea")
    assert_name_match(pat,
                      "Amanita vaginata ssp. grisea f. grisea group",
                      "Amanita vaginata ssp. grisea f. grisea")
    assert_name_match(pat,
                      "Amanita vaginata var. grisea f. grisea group",
                      "Amanita vaginata var. grisea f. grisea")
    assert_name_match(
      pat,
      "Amanita vaginata ssp. grisea var. grisea f. grisea group",
      "Amanita vaginata ssp. grisea var. grisea f. grisea"
    )
    assert_name_match(pat, "Amanita vaginata Author group", "Amanita vaginata")
    assert_name_match(pat, "Amanita vaginata group Author", "Amanita vaginata")
    assert_name_match(pat, "Amanita vaginata Amanita group", "Amanita vaginata")
    assert_name_match(pat, "Amanita vaginata clade", "Amanita vaginata")
  end

  def test_some_bad_names
    assert_name_parse_fails("Physica stellaris or aipolia")
    assert_name_parse_fails("Physica stellaris / aipolia")
    assert_name_parse_fails("Physica adscendens & Xanthoria elegans")
    assert_name_parse_fails("Physica adscendens + Xanthoria elegans")
    assert_name_parse_fails("Physica adscendens ß Xanthoria elegans")
    assert_name_parse_fails("Physica ?")
    assert_name_parse_fails("Physica adscendens .")
    assert_name_parse_fails("Physica adscendens nom.temp (Tulloss)")
    assert_name_parse_fails("Physica adscendens [nom. ined.]")
    assert_name_parse_fails("Physica sp-1 Tulloss")
    assert_name_parse_fails("Physica sp-2")
    assert_name_parse_fails("Agaricus sp-K placomyces sensu Krieger")
    assert_name_parse_fails("Agaricus test var. test ssp. test")
    assert_name_parse_fails("Agaricus test var. test sect. test")
    assert_name_parse_fails("Agaricus test Author var. test ssp. test")
    assert_name_parse_fails("Agaricus test Author var. test sect. test")
    assert_name_parse_fails("Agaricus sect. Agaricus subg. Agaricus")
    assert_name_parse_fails("Agaricus sect. Agaricus ssp. Agaricus")
    assert_name_parse_fails("Agaricus Author sect. Agaricus subg. Agaricus")
    assert_name_parse_fails("Agaricus Author sect. Agaricus ssp. Agaricus")
  end

  def test_name_parse_1
    do_name_parse_test(
      "Lecania ryaniana van den Boom",
      text_name: "Lecania ryaniana",
      real_text_name: "Lecania ryaniana",
      search_name: "Lecania ryaniana van den Boom",
      real_search_name: "Lecania ryaniana van den Boom",
      sort_name: "Lecania ryaniana  van den Boom",
      display_name: "**__Lecania__** **__ryaniana__** van den Boom",
      parent_name: "Lecania",
      rank: "Species",
      author: "van den Boom",
      deprecated: false
    )
  end

  def test_name_parse_1a
    do_name_parse_test(
      "Lecania van den Boom",
      text_name: "Lecania",
      real_text_name: "Lecania",
      search_name: "Lecania van den Boom",
      real_search_name: "Lecania van den Boom",
      sort_name: "Lecania  van den Boom",
      display_name: "**__Lecania__** van den Boom",
      parent_name: nil,
      rank: "Genus",
      author: "van den Boom",
      deprecated: false
    )
  end

  def test_name_parse_1b
    do_name_parse_test(
      "Lecania ryaniana de Hoog",
      text_name: "Lecania ryaniana",
      real_text_name: "Lecania ryaniana",
      search_name: "Lecania ryaniana de Hoog",
      real_search_name: "Lecania ryaniana de Hoog",
      sort_name: "Lecania ryaniana  de Hoog",
      display_name: "**__Lecania__** **__ryaniana__** de Hoog",
      parent_name: "Lecania",
      rank: "Species",
      author: "de Hoog",
      deprecated: false
    )
  end

  def test_name_parse_1c
    do_name_parse_test(
      "Lecania de Hoog",
      text_name: "Lecania",
      real_text_name: "Lecania",
      search_name: "Lecania de Hoog",
      real_search_name: "Lecania de Hoog",
      sort_name: "Lecania  de Hoog",
      display_name: "**__Lecania__** de Hoog",
      parent_name: nil,
      rank: "Genus",
      author: "de Hoog",
      deprecated: false
    )
  end

  def test_name_parse_1d
    do_name_parse_test(
      "Synchytrium subg. Endochytrium du Plessis",
      text_name: "Synchytrium subg. Endochytrium",
      real_text_name: "Synchytrium subg. Endochytrium",
      search_name: "Synchytrium subg. Endochytrium du Plessis",
      real_search_name: "Synchytrium subg. Endochytrium du Plessis",
      sort_name: "Synchytrium  {1subg.  Endochytrium  du Plessis",
      display_name: "**__Synchytrium__** subg. **__Endochytrium__** du Plessis",
      parent_name: "Synchytrium",
      rank: "Subgenus",
      author: "du Plessis",
      deprecated: false
    )
  end

  def test_name_parse_2
    do_name_parse_test(
      "Lecidea sanguineoatra sens. Nyl",
      text_name: "Lecidea sanguineoatra",
      real_text_name: "Lecidea sanguineoatra",
      search_name: "Lecidea sanguineoatra sensu Nyl",
      real_search_name: "Lecidea sanguineoatra sensu Nyl",
      sort_name: "Lecidea sanguineoatra  sensu Nyl",
      display_name: "**__Lecidea__** **__sanguineoatra__** sensu Nyl",
      parent_name: "Lecidea",
      rank: "Species",
      author: "sensu Nyl",
      deprecated: false
    )
  end

  def test_name_parse_3
    do_name_parse_test(
      "Acarospora squamulosa sensu Th. Fr.",
      text_name: "Acarospora squamulosa",
      real_text_name: "Acarospora squamulosa",
      search_name: "Acarospora squamulosa sensu Th. Fr.",
      real_search_name: "Acarospora squamulosa sensu Th. Fr.",
      sort_name: "Acarospora squamulosa  sensu Th. Fr.",
      display_name: "**__Acarospora__** **__squamulosa__** sensu Th. Fr.",
      parent_name: "Acarospora",
      rank: "Species",
      author: "sensu Th. Fr.",
      deprecated: false
    )
  end

  def test_name_parse_4
    do_name_parse_test(
      "Cladina portentosa subsp. pacifica f. decolorans auct.",
      text_name: "Cladina portentosa subsp. pacifica f. decolorans",
      real_text_name: "Cladina portentosa subsp. pacifica f. decolorans",
      search_name: "Cladina portentosa subsp. pacifica f. decolorans auct.",
      real_search_name:
        "Cladina portentosa subsp. pacifica f. decolorans auct.",
      sort_name:
        "Cladina portentosa  {5subsp.  pacifica  {7f.  decolorans  auct.",
      display_name:
        "**__Cladina__** **__portentosa__** subsp. **__pacifica__** " \
        "f. **__decolorans__** auct.",
      parent_name: "Cladina portentosa subsp. pacifica",
      rank: "Form",
      author: "auct.",
      deprecated: false
    )
  end

  def test_name_parse_5
    do_name_parse_test(
      "Japewia tornoënsis Somloë",
      text_name: "Japewia tornoensis",
      real_text_name: "Japewia tornoënsis",
      search_name: "Japewia tornoensis Somloë",
      real_search_name: "Japewia tornoënsis Somloë",
      sort_name: "Japewia tornoensis  Somloë",
      display_name: "**__Japewia__** **__tornoënsis__** Somloë",
      parent_name: "Japewia",
      rank: "Species",
      author: "Somloë",
      deprecated: false
    )
  end

  def test_name_parse_5a
    do_name_parse_test(
      "Japewia tornoënsis Somloë".unicode_normalize(:nfd),
      text_name: "Japewia tornoensis",
      real_text_name: "Japewia tornoënsis",
      search_name: "Japewia tornoensis Somloë",
      real_search_name: "Japewia tornoënsis Somloë",
      sort_name: "Japewia tornoensis  Somloë",
      display_name: "**__Japewia__** **__tornoënsis__** Somloë",
      parent_name: "Japewia",
      rank: "Species",
      author: "Somloë",
      deprecated: false
    )
  end

  def test_name_parse_6
    do_name_parse_test(
      'Micarea globularis "(Ach. ex Nyl.) Hedl."',
      text_name: "Micarea globularis",
      real_text_name: "Micarea globularis",
      search_name: 'Micarea globularis "(Ach. ex Nyl.) Hedl."',
      real_search_name: 'Micarea globularis "(Ach. ex Nyl.) Hedl."',
      sort_name: "Micarea globularis  (Ach. ex Nyl.) Hedl.",
      display_name: '**__Micarea__** **__globularis__** "(Ach. ex Nyl.) Hedl."',
      parent_name: "Micarea",
      rank: "Species",
      author: '"(Ach. ex Nyl.) Hedl."',
      deprecated: false
    )
  end

  def test_name_parse_7
    do_name_parse_test(
      'Synecho aggregatus ("Ach.") Th. Fr.',
      text_name: "Synecho aggregatus",
      real_text_name: "Synecho aggregatus",
      search_name: 'Synecho aggregatus ("Ach.") Th. Fr.',
      real_search_name: 'Synecho aggregatus ("Ach.") Th. Fr.',
      sort_name: "Synecho aggregatus  (Ach.) Th. Fr.",
      display_name: '**__Synecho__** **__aggregatus__** ("Ach.") Th. Fr.',
      parent_name: "Synecho",
      rank: "Species",
      author: '("Ach.") Th. Fr.',
      deprecated: false
    )
  end

  def test_name_parse_8
    do_name_parse_test(
      '"Toninia"',
      text_name: "Gen. 'Toninia'",
      real_text_name: "Gen. 'Toninia'",
      search_name: "Gen. 'Toninia'",
      real_search_name: "Gen. 'Toninia'",
      sort_name: "Toninia",
      display_name: "Gen. **__'Toninia'__**",
      parent_name: nil,
      rank: "Genus",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_9
    do_name_parse_test(
      "'Toninia' sp.",
      text_name: "Gen. 'Toninia'",
      real_text_name: "Gen. 'Toninia'",
      search_name: "Gen. 'Toninia'",
      real_search_name: "Gen. 'Toninia'",
      sort_name: "Toninia",
      display_name: "Gen. **__'Toninia'__**",
      parent_name: nil,
      rank: "Genus",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_10
    do_name_parse_test(
      "'Toninia' squalescens",
      text_name: "Gen. 'Toninia' squalescens",
      real_text_name: "Gen. 'Toninia' squalescens",
      search_name: "Gen. 'Toninia' squalescens",
      real_search_name: "Gen. 'Toninia' squalescens",
      sort_name: "Toninia squalescens",
      display_name: "Gen. **__'Toninia'__** **__squalescens__**",
      parent_name: "Gen. 'Toninia'",
      rank: "Species",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_prov_genus
    do_name_parse_test(
      "Gen. 'Toninia' squalescens",
      text_name: "Gen. 'Toninia' squalescens",
      real_text_name: "Gen. 'Toninia' squalescens",
      search_name: "Gen. 'Toninia' squalescens",
      real_search_name: "Gen. 'Toninia' squalescens",
      sort_name: "Toninia squalescens",
      display_name: "Gen. **__'Toninia'__** **__squalescens__**",
      parent_name: "Gen. 'Toninia'",
      rank: "Species",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_11
    do_name_parse_test(
      'Anaptychia "leucomelaena" auct.',
      text_name: "Anaptychia sp. 'leucomelaena'",
      real_text_name: "Anaptychia sp. 'leucomelaena'",
      search_name: "Anaptychia sp. 'leucomelaena' auct.",
      real_search_name: "Anaptychia sp. 'leucomelaena' auct.",
      sort_name: "Anaptychia leucomelaena  auct.",
      display_name: "**__Anaptychia__** sp. **__'leucomelaena'__** auct.",
      parent_name: "Anaptychia",
      rank: "Species",
      author: "auct.",
      deprecated: false
    )
  end

  def test_name_parse_prov_sp
    do_name_parse_test(
      "Anap sp. 'luna' S. Russ crypt. temp.",
      text_name: "Anap sp. 'luna'",
      real_text_name: "Anap sp. 'luna'",
      search_name: "Anap sp. 'luna' S. Russ crypt. temp.",
      real_search_name: "Anap sp. 'luna' S. Russ crypt. temp.",
      sort_name: "Anap luna  S. Russ crypt. temp.",
      display_name: "**__Anap__** sp. **__'luna'__** S. Russ crypt. temp.",
      parent_name: "Anap",
      rank: "Species",
      author: "S. Russ crypt. temp.",
      deprecated: false
    )
  end

  def test_name_parse_prov_gen
    do_name_parse_test(
      'Gen. "Snap" luna S. Russ crypt. temp.',
      text_name: "Gen. 'Snap' luna",
      real_text_name: "Gen. 'Snap' luna",
      search_name: "Gen. 'Snap' luna S. Russ crypt. temp.",
      real_search_name: "Gen. 'Snap' luna S. Russ crypt. temp.",
      sort_name: "Snap luna  S. Russ crypt. temp.",
      display_name: "Gen. **__'Snap'__** **__luna__** S. Russ crypt. temp.",
      parent_name: "Gen. 'Snap'",
      rank: "Species",
      author: "S. Russ crypt. temp.",
      deprecated: false
    )
  end

  def test_name_parse_prov_gen_sp
    do_name_parse_test(
      "Gen. 'Snap' sp. 'luna' Russ crypt. temp.",
      text_name: "Gen. 'Snap' sp. 'luna'",
      real_text_name: "Gen. 'Snap' sp. 'luna'",
      search_name: "Gen. 'Snap' sp. 'luna' Russ crypt. temp.",
      real_search_name: "Gen. 'Snap' sp. 'luna' Russ crypt. temp.",
      sort_name: "Snap luna  Russ crypt. temp.",
      display_name: "Gen. **__'Snap'__** sp. **__'luna'__** Russ crypt. temp.",
      parent_name: "Gen. 'Snap'",
      rank: "Species",
      author: "Russ crypt. temp.",
      deprecated: false
    )
  end

  def test_name_parse_12
    do_name_parse_test(
      "Anema",
      text_name: "Anema",
      real_text_name: "Anema",
      search_name: "Anema",
      real_search_name: "Anema",
      sort_name: "Anema",
      display_name: "**__Anema__**",
      parent_name: nil,
      rank: "Genus",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_13
    do_name_parse_test(
      "Anema sp",
      text_name: "Anema",
      real_text_name: "Anema",
      search_name: "Anema",
      real_search_name: "Anema",
      sort_name: "Anema",
      display_name: "**__Anema__**",
      parent_name: nil,
      rank: "Genus",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_14
    do_name_parse_test(
      "Anema sp.",
      text_name: "Anema",
      real_text_name: "Anema",
      search_name: "Anema",
      real_search_name: "Anema",
      sort_name: "Anema",
      display_name: "**__Anema__**",
      parent_name: nil,
      rank: "Genus",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_15
    do_name_parse_test(
      "Anema Nyl. ex Forss.",
      text_name: "Anema",
      real_text_name: "Anema",
      search_name: "Anema Nyl. ex Forss.",
      real_search_name: "Anema Nyl. ex Forss.",
      sort_name: "Anema  Nyl. ex Forss.",
      display_name: "**__Anema__** Nyl. ex Forss.",
      parent_name: nil,
      rank: "Genus",
      author: "Nyl. ex Forss.",
      deprecated: false
    )
  end

  def test_name_parse_16
    do_name_parse_test(
      "Anema sp Nyl. ex Forss.",
      text_name: "Anema",
      real_text_name: "Anema",
      search_name: "Anema Nyl. ex Forss.",
      real_search_name: "Anema Nyl. ex Forss.",
      sort_name: "Anema  Nyl. ex Forss.",
      display_name: "**__Anema__** Nyl. ex Forss.",
      parent_name: nil,
      rank: "Genus",
      author: "Nyl. ex Forss.",
      deprecated: false
    )
  end

  def test_name_parse_17
    do_name_parse_test(
      "Anema sp. Nyl. ex Forss.",
      text_name: "Anema",
      real_text_name: "Anema",
      search_name: "Anema Nyl. ex Forss.",
      real_search_name: "Anema Nyl. ex Forss.",
      sort_name: "Anema  Nyl. ex Forss.",
      display_name: "**__Anema__** Nyl. ex Forss.",
      parent_name: nil,
      rank: "Genus",
      author: "Nyl. ex Forss.",
      deprecated: false
    )
  end

  def test_name_parse_18
    do_name_parse_test(
      "Japewia toënsis var. toënsis",
      text_name: "Japewia toensis var. toensis",
      real_text_name: "Japewia toënsis var. toënsis",
      search_name: "Japewia toensis var. toensis",
      real_search_name: "Japewia toënsis var. toënsis",
      sort_name: "Japewia toensis  {6var.  !toensis",
      display_name: "**__Japewia__** **__toënsis__** var. **__toënsis__**",
      parent_name: "Japewia toënsis",
      rank: "Variety",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_19
    do_name_parse_test(
      "Does this ssp. ever var. happen f. for Real?",
      text_name: "Does this subsp. ever var. happen f. for",
      real_text_name: "Does this subsp. ever var. happen f. for",
      search_name: "Does this subsp. ever var. happen f. for Real?",
      real_search_name: "Does this subsp. ever var. happen f. for Real?",
      sort_name: "Does this  {5subsp.  ever  {6var.  happen  {7f.  for  Real?",
      display_name: "**__Does__** **__this__** subsp. **__ever__** " \
                    "var. **__happen__** f. **__for__** Real?",
      parent_name: "Does this subsp. ever var. happen",
      rank: "Form",
      author: "Real?",
      deprecated: false
    )
  end

  def test_name_parse_19a
    name = "Gen. 'Does' sp. 'this' subsp. 'ever' var. 'happen' f. 'for'"
    author = "Real?"
    full_name = "#{name} #{author}"
    do_name_parse_test(
      full_name,
      text_name: name,
      real_text_name: name,
      search_name: full_name,
      real_search_name: full_name,
      sort_name: "Does this  {5subsp.  ever  {6var.  happen  {7f.  for  Real?",
      display_name: "Gen. **__'Does'__** sp. **__'this'__** " \
                    "subsp. **__'ever'__** var. **__'happen'__** " \
                    "f. **__'for'__** Real?",
      parent_name: "Gen. 'Does' sp. 'this' subsp. 'ever' var. 'happen'",
      rank: "Form",
      author: author,
      deprecated: false
    )
  end

  def test_name_parse_19b
    name = "Gen. 'Does' sp. 'this' subsp. 'happen'"
    do_name_parse_test(
      "Gen. 'Does' sp. 'this' ssp. 'happen'",
      text_name: name,
      real_text_name: name,
      search_name: name,
      real_search_name: name,
      sort_name: "Does this  {5subsp.  happen",
      display_name: "Gen. **__'Does'__** sp. **__'this'__** " \
                    "subsp. **__'happen'__**",
      parent_name: "Gen. 'Does' sp. 'this'",
      rank: "Subspecies",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_20
    do_name_parse_test(
      "Boletus  rex-veris Arora & Simonini",
      text_name: "Boletus rex-veris",
      real_text_name: "Boletus rex-veris",
      search_name: "Boletus rex-veris Arora & Simonini",
      real_search_name: "Boletus rex-veris Arora & Simonini",
      sort_name: "Boletus rex-veris  Arora & Simonini",
      display_name: "**__Boletus__** **__rex-veris__** Arora & Simonini",
      parent_name: "Boletus",
      rank: "Species",
      author: "Arora & Simonini",
      deprecated: false
    )
  end

  def test_name_parse_21
    do_name_parse_test(
      "Amanita 'quoted'",
      text_name: "Amanita sp. 'quoted'",
      real_text_name: "Amanita sp. 'quoted'",
      search_name: "Amanita sp. 'quoted'",
      real_search_name: "Amanita sp. 'quoted'",
      sort_name: "Amanita quoted",
      display_name: "**__Amanita__** sp. **__'quoted'__**",
      parent_name: "Amanita",
      rank: "Species",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_22
    do_name_parse_test(
      "Amanita Sp.",
      text_name: "Amanita",
      real_text_name: "Amanita",
      search_name: "Amanita",
      real_search_name: "Amanita",
      sort_name: "Amanita",
      display_name: "**__Amanita__**",
      parent_name: nil,
      rank: "Genus",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_23
    do_name_parse_test(
      "Amanita Sect. Vaginatae (L.) Ach.",
      text_name: "Amanita sect. Vaginatae",
      real_text_name: "Amanita sect. Vaginatae",
      search_name: "Amanita sect. Vaginatae (L.) Ach.",
      real_search_name: "Amanita sect. Vaginatae (L.) Ach.",
      sort_name: "Amanita  {2sect.  Vaginatae  (L.) Ach.",
      display_name: "**__Amanita__** sect. **__Vaginatae__** (L.) Ach.",
      parent_name: "Amanita",
      rank: "Section",
      author: "(L.) Ach.",
      deprecated: false
    )
  end

  def test_name_parse_25
    do_name_parse_test(
      "Amanita stirps Vaginatae Ach. & Fr.",
      text_name: "Amanita stirps Vaginatae",
      real_text_name: "Amanita stirps Vaginatae",
      search_name: "Amanita stirps Vaginatae Ach. & Fr.",
      real_search_name: "Amanita stirps Vaginatae Ach. & Fr.",
      sort_name: "Amanita  {4stirps  Vaginatae  Ach. & Fr.",
      display_name: "**__Amanita__** stirps **__Vaginatae__** Ach. & Fr.",
      parent_name: "Amanita",
      rank: "Stirps",
      author: "Ach. & Fr.",
      deprecated: false
    )
  end

  def test_name_parse_26
    do_name_parse_test(
      "Amanita subgenus Vaginatae stirps Vaginatae",
      text_name: "Amanita subg. Vaginatae stirps Vaginatae",
      real_text_name: "Amanita subg. Vaginatae stirps Vaginatae",
      search_name: "Amanita subg. Vaginatae stirps Vaginatae",
      real_search_name: "Amanita subg. Vaginatae stirps Vaginatae",
      sort_name: "Amanita  {1subg.  Vaginatae  {4stirps  !Vaginatae",
      display_name:
        "**__Amanita__** subg. **__Vaginatae__** stirps **__Vaginatae__**",
      parent_name: "Amanita subg. Vaginatae",
      rank: "Stirps",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_27
    do_name_parse_test(
      "Amanita 'sp-S01'",
      text_name: "Amanita sp. 'S01'",
      real_text_name: "Amanita sp. 'S01'",
      search_name: "Amanita sp. 'S01'",
      real_search_name: "Amanita sp. 'S01'",
      sort_name: "Amanita s01",
      display_name: "**__Amanita__** sp. **__'S01'__**",
      parent_name: "Amanita",
      rank: "Species",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_28
    do_name_parse_test(
      "Amanita 'sp-S01' Tulloss",
      text_name: "Amanita sp. 'S01'",
      real_text_name: "Amanita sp. 'S01'",
      search_name: "Amanita sp. 'S01' Tulloss",
      real_search_name: "Amanita sp. 'S01' Tulloss",
      sort_name: "Amanita s01  Tulloss",
      display_name: "**__Amanita__** sp. **__'S01'__** Tulloss",
      parent_name: "Amanita",
      rank: "Species",
      author: "Tulloss",
      deprecated: false
    )
  end

  def test_name_parse_29
    do_name_parse_test(
      "Amanita Wrong Author",
      text_name: "Amanita",
      real_text_name: "Amanita",
      search_name: "Amanita Wrong Author",
      real_search_name: "Amanita Wrong Author",
      sort_name: "Amanita  Wrong Author",
      display_name: "**__Amanita__** Wrong Author",
      parent_name: nil,
      rank: "Genus",
      author: "Wrong Author",
      deprecated: false
    )
  end

  def test_name_parse_30
    do_name_parse_test(
      "Amanita vaginata \u2028",
      text_name: "Amanita vaginata",
      real_text_name: "Amanita vaginata",
      search_name: "Amanita vaginata",
      real_search_name: "Amanita vaginata",
      sort_name: "Amanita vaginata",
      display_name: "**__Amanita__** **__vaginata__**",
      parent_name: "Amanita",
      rank: "Species",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_32
    do_name_parse_test(
      "Pleurotus djamor (Fr.) Boedijn var. djamor",
      text_name: "Pleurotus djamor var. djamor",
      real_text_name: "Pleurotus djamor var. djamor",
      search_name: "Pleurotus djamor var. djamor (Fr.) Boedijn",
      real_search_name: "Pleurotus djamor (Fr.) Boedijn var. djamor",
      sort_name: "Pleurotus djamor  {6var.  !djamor  (Fr.) Boedijn",
      display_name:
        "**__Pleurotus__** **__djamor__** (Fr.) Boedijn var. **__djamor__**",
      parent_name: "Pleurotus djamor",
      rank: "Variety",
      author: "(Fr.) Boedijn",
      deprecated: false
    )
  end

  def test_name_parse_33
    do_name_parse_test(
      "Pleurotus sp. T44 Tulloss",
      text_name: "Pleurotus sp. 'T44'",
      real_text_name: "Pleurotus sp. 'T44'",
      search_name: "Pleurotus sp. 'T44' Tulloss",
      real_search_name: "Pleurotus sp. 'T44' Tulloss",
      sort_name: "Pleurotus t44  Tulloss",
      display_name: "**__Pleurotus__** sp. **__'T44'__** Tulloss",
      parent_name: "Pleurotus",
      rank: "Species",
      author: "Tulloss",
      deprecated: false
    )
  end

  def test_name_parse_34
    do_name_parse_test(
      "Xylaria species",
      text_name: "Xylaria",
      real_text_name: "Xylaria",
      search_name: "Xylaria",
      real_search_name: "Xylaria",
      sort_name: "Xylaria",
      display_name: "**__Xylaria__**",
      parent_name: nil,
      rank: "Genus",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_35
    do_name_parse_test(
      "Amanita sect. Amanita Pers.",
      text_name: "Amanita sect. Amanita",
      real_text_name: "Amanita sect. Amanita",
      search_name: "Amanita sect. Amanita Pers.",
      real_search_name: "Amanita Pers. sect. Amanita",
      sort_name: "Amanita  {2sect.  !Amanita  Pers.",
      display_name: "**__Amanita__** Pers. sect. **__Amanita__**",
      parent_name: "Amanita",
      rank: "Section",
      author: "Pers.",
      deprecated: false
    )
  end

  def test_name_parse_36
    do_name_parse_test(
      "Amanita Pers. sect. Amanita",
      text_name: "Amanita sect. Amanita",
      real_text_name: "Amanita sect. Amanita",
      search_name: "Amanita sect. Amanita Pers.",
      real_search_name: "Amanita Pers. sect. Amanita",
      sort_name: "Amanita  {2sect.  !Amanita  Pers.",
      display_name: "**__Amanita__** Pers. sect. **__Amanita__**",
      parent_name: "Amanita",
      rank: "Section",
      author: "Pers.",
      deprecated: false
    )
  end

  def test_name_parse_37
    do_name_parse_test(
      "Amanita subg. Amidella Singer sect. Amidella stirps Amidella",
      text_name: "Amanita subg. Amidella sect. Amidella stirps Amidella",
      real_text_name:
        "Amanita subg. Amidella sect. Amidella stirps Amidella",
      search_name:
        "Amanita subg. Amidella sect. Amidella stirps Amidella Singer",
      real_search_name:
        "Amanita subg. Amidella Singer sect. Amidella stirps Amidella",
      sort_name:
        "Amanita  {1subg.  Amidella  {2sect.  !Amidella  {4stirps  " \
        "!Amidella  Singer",
      display_name:
        "**__Amanita__** subg. **__Amidella__** Singer " \
        "sect. **__Amidella__** stirps **__Amidella__**",
      parent_name: "Amanita subg. Amidella sect. Amidella",
      rank: "Stirps",
      author: "Singer",
      deprecated: false
    )
  end

  def test_name_parse_38
    do_name_parse_test(
      "Podoscyphaceae sensu Reid",
      text_name: "Podoscyphaceae",
      real_text_name: "Podoscyphaceae",
      search_name: "Podoscyphaceae sensu Reid",
      real_search_name: "Podoscyphaceae sensu Reid",
      sort_name: "Podoscyph!7  sensu Reid",
      display_name: "**__Podoscyphaceae__** sensu Reid",
      parent_name: nil,
      rank: "Family",
      author: "sensu Reid",
      deprecated: false
    )
  end

  def test_name_parse_39
    do_name_parse_test(
      "Fossil-Ascomycetes",
      text_name: "Fossil-Ascomycetes",
      real_text_name: "Fossil-Ascomycetes",
      search_name: "Fossil-Ascomycetes",
      real_search_name: "Fossil-Ascomycetes",
      sort_name: "Fossil-Asc!3",
      display_name: "**__Fossil-Ascomycetes__**",
      parent_name: nil,
      rank: "Class",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_40
    do_name_parse_test(
      "Fossil-Fungi",
      text_name: "Fossil-Fungi",
      real_text_name: "Fossil-Fungi",
      search_name: "Fossil-Fungi",
      real_search_name: "Fossil-Fungi",
      sort_name: "Fossil-Fungi",
      display_name: "**__Fossil-Fungi__**",
      parent_name: nil,
      rank: "Phylum",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_41
    do_name_parse_test(
      "Armillaria mellea D.\tC.",
      text_name: "Armillaria mellea",
      real_text_name: "Armillaria mellea",
      search_name: "Armillaria mellea D.C.",
      real_search_name: "Armillaria mellea D.C.",
      sort_name: "Armillaria mellea  D.C.",
      display_name: "**__Armillaria__** **__mellea__** D.C.",
      parent_name: "Armillaria",
      rank: "Species",
      author: "D.C.",
      deprecated: false
    )
  end

  def test_name_parse_42
    do_name_parse_test(
      'Strobilomyces strobilaceus var. "mexicanus" R. Heim',
      text_name: "Strobilomyces strobilaceus var. 'mexicanus'",
      real_text_name: "Strobilomyces strobilaceus var. 'mexicanus'",
      search_name: "Strobilomyces strobilaceus var. 'mexicanus' R. Heim",
      real_search_name: "Strobilomyces strobilaceus var. 'mexicanus' R. Heim",
      sort_name: "Strobilomyces strobilaceus  {6var.  mexicanus  R. Heim",
      display_name: "**__Strobilomyces__** **__strobilaceus__** " \
                    "var. **__'mexicanus'__** R. Heim",
      parent_name: "Strobilomyces strobilaceus",
      rank: "Variety",
      author: "R. Heim",
      deprecated: false
    )
  end

  def test_name_prov_name_with_periods
    do_name_parse_test(
      "Agaricus sp. 'A.G.'",
      text_name: "Agaricus sp. 'A.G.'",
      real_text_name: "Agaricus sp. 'A.G.'",
      search_name: "Agaricus sp. 'A.G.'",
      real_search_name: "Agaricus sp. 'A.G.'",
      sort_name: "Agaricus a.g.",
      display_name: "**__Agaricus__** sp. **__'A.G.'__**",
      parent_name: "Agaricus",
      rank: "Species",
      author: "",
      deprecated: false
    )
  end

  def test_name_prov_name_no_quotes
    do_name_parse_test(
      "Pleurotus pulmonarius-PNW02",
      text_name: "Pleurotus sp. 'pulmonarius-PNW02'",
      real_text_name: "Pleurotus sp. 'pulmonarius-PNW02'",
      search_name: "Pleurotus sp. 'pulmonarius-PNW02'",
      real_search_name: "Pleurotus sp. 'pulmonarius-PNW02'",
      sort_name: "Pleurotus pulmonarius-pnw02",
      display_name: "**__Pleurotus__** sp. **__'pulmonarius-PNW02'__**",
      parent_name: "Pleurotus",
      rank: "Species",
      author: "",
      deprecated: false
    )
  end

  def test_name_prov_name_with_spaces
    do_name_parse_test(
      "Pleurotus 'pulmonarius PNW02'",
      text_name: "Pleurotus sp. 'pulmonarius-PNW02'",
      real_text_name: "Pleurotus sp. 'pulmonarius-PNW02'",
      search_name: "Pleurotus sp. 'pulmonarius-PNW02'",
      real_search_name: "Pleurotus sp. 'pulmonarius-PNW02'",
      sort_name: "Pleurotus pulmonarius-pnw02",
      display_name: "**__Pleurotus__** sp. **__'pulmonarius-PNW02'__**",
      parent_name: "Pleurotus",
      rank: "Species",
      author: "",
      deprecated: false
    )
  end

  def test_name_prov_name_with_nonbreaking_space
    # leading non-breaking space (U+00A0)
    do_name_parse_test(
      "\u00A0Cuphophyllus \"pratensis-IN01\"",
      text_name: "Cuphophyllus sp. 'pratensis-IN01'",
      real_text_name: "Cuphophyllus sp. 'pratensis-IN01'",
      search_name: "Cuphophyllus sp. 'pratensis-IN01'",
      real_search_name: "Cuphophyllus sp. 'pratensis-IN01'",
      sort_name: "Cuphophyllus pratensis-in01",
      display_name: "**__Cuphophyllus__** sp. **__'pratensis-IN01'__**",
      parent_name: "Cuphophyllus",
      rank: "Species",
      author: "",
      deprecated: false
    )
    # trailing non-breaking space
    do_name_parse_test(
      "Cuphophyllus \"pratensis-IN01\"\u00A0",
      text_name: "Cuphophyllus sp. 'pratensis-IN01'",
      real_text_name: "Cuphophyllus sp. 'pratensis-IN01'",
      search_name: "Cuphophyllus sp. 'pratensis-IN01'",
      real_search_name: "Cuphophyllus sp. 'pratensis-IN01'",
      sort_name: "Cuphophyllus pratensis-in01",
      display_name: "**__Cuphophyllus__** sp. **__'pratensis-IN01'__**",
      parent_name: "Cuphophyllus",
      rank: "Species",
      author: "",
      deprecated: false
    )
    # interior non-breaking space
    do_name_parse_test(
      "Cuphophyllus \u00A0\"pratensis-IN01\"",
      text_name: "Cuphophyllus sp. 'pratensis-IN01'",
      real_text_name: "Cuphophyllus sp. 'pratensis-IN01'",
      search_name: "Cuphophyllus sp. 'pratensis-IN01'",
      real_search_name: "Cuphophyllus sp. 'pratensis-IN01'",
      sort_name: "Cuphophyllus pratensis-in01",
      display_name: "**__Cuphophyllus__** sp. **__'pratensis-IN01'__**",
      parent_name: "Cuphophyllus",
      rank: "Species",
      author: "",
      deprecated: false
    )
  end

  def test_name_prov_name_no_epithet
    do_name_parse_test(
      "Pleurotus 'MA02'",
      text_name: "Pleurotus sp. 'MA02'",
      real_text_name: "Pleurotus sp. 'MA02'",
      search_name: "Pleurotus sp. 'MA02'",
      real_search_name: "Pleurotus sp. 'MA02'",
      sort_name: "Pleurotus ma02",
      display_name: "**__Pleurotus__** sp. **__'MA02'__**",
      parent_name: "Pleurotus",
      rank: "Species",
      author: "",
      deprecated: false
    )
  end

  def test_name_parse_comb
    do_name_parse_test(
      "Sebacina schweinitzii comb prov",
      text_name: "Sebacina schweinitzii",
      real_text_name: "Sebacina schweinitzii",
      search_name: "Sebacina schweinitzii comb. prov.",
      real_search_name: "Sebacina schweinitzii comb. prov.",
      sort_name: "Sebacina schweinitzii  comb. prov.",
      display_name: "**__Sebacina__** **__schweinitzii__** comb. prov.",
      parent_name: "Sebacina",
      rank: "Species",
      author: "comb. prov.",
      deprecated: false
    )
  end

  def test_name_parse_group_names
    do_name_parse_test( # monomial, no author
      "Agaricus group",
      text_name: "Agaricus group",
      real_text_name: "Agaricus group",
      search_name: "Agaricus group",
      real_search_name: "Agaricus group",
      sort_name: "Agaricus   group",
      display_name: "**__Agaricus__** group",
      parent_name: "",
      rank: "Group",
      author: "",
      deprecated: false
    )
    do_name_parse_test( # binomial, no author
      "Agaricus campestris group",
      text_name: "Agaricus campestris group",
      real_text_name: "Agaricus campestris group",
      search_name: "Agaricus campestris group",
      real_search_name: "Agaricus campestris group",
      sort_name: "Agaricus campestris   group",
      display_name: "**__Agaricus__** **__campestris__** group",
      parent_name: "Agaricus",
      rank: "Group",
      author: "",
      deprecated: false
    )
    do_name_parse_test( # monomial, with author
      "Agaricus group Author",
      text_name: "Agaricus group",
      real_text_name: "Agaricus group",
      search_name: "Agaricus group Author",
      real_search_name: "Agaricus group Author",
      sort_name: "Agaricus   group  Author",
      display_name: "**__Agaricus__** group Author",
      parent_name: "",
      rank: "Group",
      author: "Author",
      deprecated: false
    )
    do_name_parse_test( # binomial, author
      "Agaricus campestris group Author",
      text_name: "Agaricus campestris group",
      real_text_name: "Agaricus campestris group",
      search_name: "Agaricus campestris group Author",
      real_search_name: "Agaricus campestris group Author",
      sort_name: "Agaricus campestris   group  Author",
      display_name: "**__Agaricus__** **__campestris__** group Author",
      parent_name: "Agaricus",
      rank: "Group",
      author: "Author",
      deprecated: false
    )
    do_name_parse_test( # binomial with author, "group" at end
      "Agaricus campestris Author group",
      text_name: "Agaricus campestris group",
      real_text_name: "Agaricus campestris group",
      search_name: "Agaricus campestris group Author",
      real_search_name: "Agaricus campestris group Author",
      sort_name: "Agaricus campestris   group  Author",
      display_name: "**__Agaricus__** **__campestris__** group Author",
      parent_name: "Agaricus",
      rank: "Group",
      author: "Author",
      deprecated: false
    )
    do_name_parse_test( # binomial, sensu author
      "Agaricus campestris group sensu Author",
      text_name: "Agaricus campestris group",
      real_text_name: "Agaricus campestris group",
      search_name: "Agaricus campestris group sensu Author",
      real_search_name: "Agaricus campestris group sensu Author",
      sort_name: "Agaricus campestris   group  sensu Author",
      display_name: "**__Agaricus__** **__campestris__** group sensu Author",
      parent_name: "Agaricus",
      rank: "Group",
      author: "sensu Author",
      deprecated: false
    )
    do_name_parse_test( # species with Tulloss form of sp. nov.
      "Pleurotus sp. T44 group Tulloss",
      text_name: "Pleurotus sp. 'T44' group",
      real_text_name: "Pleurotus sp. 'T44' group",
      search_name: "Pleurotus sp. 'T44' group Tulloss",
      real_search_name: "Pleurotus sp. 'T44' group Tulloss",
      sort_name: "Pleurotus t44   group  Tulloss",
      display_name: "**__Pleurotus__** sp. **__'T44'__** group Tulloss",
      parent_name: "Pleurotus",
      rank: "Group",
      author: "Tulloss",
      deprecated: false
    )
    do_name_parse_test( # subgenus group, with author
      "Amanita subg. Vaginatae group (L.) Ach.",
      text_name: "Amanita subg. Vaginatae group",
      real_text_name: "Amanita subg. Vaginatae group",
      search_name: "Amanita subg. Vaginatae group (L.) Ach.",
      real_search_name: "Amanita subg. Vaginatae group (L.) Ach.",
      sort_name: "Amanita  {1subg.  Vaginatae   group  (L.) Ach.",
      display_name:
        "**__Amanita__** subg. **__Vaginatae__** group (L.) Ach.",
      parent_name: "Amanita",
      rank: "Group",
      author: "(L.) Ach.",
      deprecated: false
    )
    do_name_parse_test( # stirps group, with sub-genus parent
      "Amanita subgenus Vaginatae stirps Vaginatae group",
      text_name: "Amanita subg. Vaginatae stirps Vaginatae group",
      real_text_name: "Amanita subg. Vaginatae stirps Vaginatae group",
      search_name: "Amanita subg. Vaginatae stirps Vaginatae group",
      real_search_name: "Amanita subg. Vaginatae stirps Vaginatae group",
      sort_name:
        "Amanita  {1subg.  Vaginatae  {4stirps  !Vaginatae   group",
      display_name:
        "**__Amanita__** subg. **__Vaginatae__** stirps " \
        "**__Vaginatae__** group",
      parent_name: "Amanita subg. Vaginatae",
      rank: "Group",
      author: "",
      deprecated: false
    )
    do_name_parse_test( # binomial, "group" part of epithet
      "Agaricus grouperi group Author",
      text_name: "Agaricus grouperi group",
      real_text_name: "Agaricus grouperi group",
      search_name: "Agaricus grouperi group Author",
      real_search_name: "Agaricus grouperi group Author",
      sort_name: "Agaricus grouperi   group  Author",
      display_name: "**__Agaricus__** **__grouperi__** group Author",
      parent_name: "Agaricus",
      rank: "Group",
      author: "Author",
      deprecated: false
    )
    do_name_parse_test( # author duplicates a word in the taxon
      "Agaricus group Agaricus",
      text_name: "Agaricus group",
      real_text_name: "Agaricus group",
      search_name: "Agaricus group Agaricus",
      real_search_name: "Agaricus group Agaricus",
      sort_name: "Agaricus   group  Agaricus",
      display_name: "**__Agaricus__** group Agaricus",
      parent_name: "",
      rank: "Group",
      author: "Agaricus",
      deprecated: false
    )
  end

  def test_name_parse_clade_names
    do_name_parse_test( # monomial, no author
      "Agaricus clade",
      text_name: "Agaricus clade",
      real_text_name: "Agaricus clade",
      search_name: "Agaricus clade",
      real_search_name: "Agaricus clade",
      sort_name: "Agaricus   clade",
      display_name: "**__Agaricus__** clade",
      parent_name: "",
      rank: "Group",
      author: "",
      deprecated: false
    )
    do_name_parse_test( # binomial, no author
      "Agaricus campestris clade",
      text_name: "Agaricus campestris clade",
      real_text_name: "Agaricus campestris clade",
      search_name: "Agaricus campestris clade",
      real_search_name: "Agaricus campestris clade",
      sort_name: "Agaricus campestris   clade",
      display_name: "**__Agaricus__** **__campestris__** clade",
      parent_name: "Agaricus",
      rank: "Group",
      author: "",
      deprecated: false
    )
    do_name_parse_test( # binomial, sensu author
      "Agaricus campestris clade sensu Author",
      text_name: "Agaricus campestris clade",
      real_text_name: "Agaricus campestris clade",
      search_name: "Agaricus campestris clade sensu Author",
      real_search_name: "Agaricus campestris clade sensu Author",
      sort_name: "Agaricus campestris   clade  sensu Author",
      display_name: "**__Agaricus__** **__campestris__** clade sensu Author",
      parent_name: "Agaricus",
      rank: "Group",
      author: "sensu Author",
      deprecated: false
    )
    do_name_parse_test( # binomial with author, "clade" at end
      "Agaricus campestris Author clade",
      text_name: "Agaricus campestris clade",
      real_text_name: "Agaricus campestris clade",
      search_name: "Agaricus campestris clade Author",
      real_search_name: "Agaricus campestris clade Author",
      sort_name: "Agaricus campestris   clade  Author",
      display_name: "**__Agaricus__** **__campestris__** clade Author",
      parent_name: "Agaricus",
      rank: "Group",
      author: "Author",
      deprecated: false
    )
  end

  def test_name_parse_deprecated
    do_name_parse_test(
      "Lecania ryaniana van den Boom",
      text_name: "Lecania ryaniana",
      real_text_name: "Lecania ryaniana",
      search_name: "Lecania ryaniana van den Boom",
      real_search_name: "Lecania ryaniana van den Boom",
      sort_name: "Lecania ryaniana  van den Boom",
      display_name: "__Lecania__ __ryaniana__ van den Boom",
      parent_name: "Lecania",
      rank: "Species",
      author: "van den Boom",
      deprecated: true
    )
    do_name_parse_test( # binomial, no author, deprecated
      "Agaricus campestris group",
      text_name: "Agaricus campestris group",
      real_text_name: "Agaricus campestris group",
      search_name: "Agaricus campestris group",
      real_search_name: "Agaricus campestris group",
      sort_name: "Agaricus campestris   group",
      display_name: "__Agaricus__ __campestris__ group",
      parent_name: "Agaricus",
      rank: "Group",
      author: "",
      deprecated: true
    )
    do_name_parse_test( # binomial, sensu author, deprecated
      "Agaricus campestris group sensu Author",
      text_name: "Agaricus campestris group",
      real_text_name: "Agaricus campestris group",
      search_name: "Agaricus campestris group sensu Author",
      real_search_name: "Agaricus campestris group sensu Author",
      sort_name: "Agaricus campestris   group  sensu Author",
      display_name: "__Agaricus__ __campestris__ group sensu Author",
      parent_name: "Agaricus",
      rank: "Group",
      author: "sensu Author",
      deprecated: true
    )
  end
end
