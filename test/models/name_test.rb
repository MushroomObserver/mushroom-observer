# frozen_string_literal: true

require("test_helper")

# Tests for methods in models/name.rb and models/name/xxx.rb
class NameTest < UnitTestCase
  def create_test_name(string, force_rank = nil)
    User.current = rolf
    parse = Name.parse_name(string)
    assert(parse, "Expected this to parse: #{string}")
    params = parse.params
    params[:rank] = force_rank if force_rank
    name = Name.new_name(params)
    assert(name.save, "Error saving name \"#{string}\": [#{name.dump_errors}]")
    name
  end

  # Parse a string, with detailed error message.
  def do_name_parse_test(str, expects, deprecated: false)
    parse = Name.parse_name(str, deprecated: deprecated)
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

  def do_parse_classification_test(text, expected)
    parse = Name.parse_classification(text)
    assert_equal(expected, parse)
  rescue RuntimeError => e
    raise(e) if expected
  end

  def do_validate_classification_test(rank, text, expected)
    result = Name.validate_classification(rank, text)
    assert(expected == result)
  rescue RuntimeError => e
    raise(e) if expected
  end

  ##############################################################################

  # ----------------------------
  #  Test name parsing.
  # ----------------------------

  def test_find_or_create_name_and_parents
    # Coprinus comatus already has an author.
    # Create new subspecies Coprinus comatus v. bogus and make sure it doesn't
    # create a duplicate species if one already exists.
    # Saw this bug 20080114 -JPH
    result = Name.find_or_create_name_and_parents(
      "Coprinus comatus v. bogus (With) Author"
    )
    assert_equal(3, result.length)
    assert_equal(names(:coprinus).id, result[0].id)
    assert_equal(names(:coprinus_comatus).id, result[1].id)
    assert_nil(result[2].id)
    assert_equal("Coprinus", result[0].text_name)
    assert_equal("Coprinus comatus", result[1].text_name)
    assert_equal("Coprinus comatus var. bogus", result[2].text_name)
    assert_equal("", result[0].author)
    assert_equal("(O.F. Müll.) Pers.", result[1].author)
    assert_equal("(With) Author", result[2].author)

    # Conocybe filaris does not have an author.
    result = Name.find_or_create_name_and_parents(
      "Conocybe filaris var bogus (With) Author"
    )
    assert_equal(3, result.length)
    assert_equal(names(:conocybe).id, result[0].id)
    assert_equal(names(:conocybe_filaris).id, result[1].id)
    assert_nil(result[2].id)
    assert_equal("Conocybe", result[0].text_name)
    assert_equal("Conocybe filaris", result[1].text_name)
    assert_equal("Conocybe filaris var. bogus", result[2].text_name)
    assert_equal("", result[0].author)
    assert_equal("", result[1].author)
    assert_equal("(With) Author", result[2].author)

    # Agaricus fixture does not have an author.
    result = Name.find_or_create_name_and_parents("Agaricus L.")
    assert_equal(1, result.length)
    assert_equal(names(:agaricus).id, result[0].id)
    assert_equal("Agaricus", result[0].text_name)
    assert_equal("L.", result[0].author)

    # Agaricus does not have an author.
    result = Name.find_or_create_name_and_parents(
      "Agaricus abra f. cadabra (With) Another Author"
    )
    assert_equal(3, result.length)
    assert_equal(names(:agaricus).id, result[0].id)
    assert_nil(result[1].id)
    assert_nil(result[2].id)
    assert_equal("Agaricus", result[0].text_name)
    assert_equal("Agaricus abra", result[1].text_name)
    assert_equal("Agaricus abra f. cadabra", result[2].text_name)
    assert_equal("", result[0].author)
    assert_equal("", result[1].author)
    assert_equal("(With) Another Author", result[2].author)
  end

  def test_standardize_name
    assert_equal("Amanita", Name.standardize_name("Amanita"))
    assert_equal("Amanita subgenus Vaginatae",
                 Name.standardize_name("Amanita SUBG. Vaginatae"))
    assert_equal("Amanita subsect. Vaginatae",
                 Name.standardize_name("Amanita subsect Vaginatae"))
    assert_equal("Amanita stirps Vaginatae",
                 Name.standardize_name("Amanita Stirps Vaginatae"))
    assert_equal(
      "Amanita subgenus One sect. Two stirps Three",
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

  def test_format_string
    assert_equal(
      "**__Amanita__**",
      Name.format_name("Amanita")
    )
    assert_equal(
      "**__Amanita sp.__**",
      Name.format_name("Amanita sp.")
    )
    assert_equal(
      "**__Amanita__** sect. **__Vaginatae__**",
      Name.format_name("Amanita sect. Vaginatae")
    )
    assert_equal(
      "**__Amanita__** subg. **__One__** subsect. **__Two__** stirps **__Three__**", # rubocop:disable Layout/LineLength
      Name.format_name("Amanita subg. One subsect. Two stirps Three")
    )
    assert_equal(
      "**__Amanita vaginata__**",
      Name.format_name("Amanita vaginata")
    )
    assert_equal(
      "**__Amanita vaginata__** subsp. **__grisea__**",
      Name.format_name("Amanita vaginata subsp. grisea")
    )
    assert_equal(
      "**__Amanita vaginata__** subsp. **__one__** var. **__two__** f. **__three__**", # rubocop:disable Layout/LineLength
      Name.format_name("Amanita vaginata subsp. one var. two f. three")
    )
    assert_equal(
      "__Amanita__", Name.format_name("Amanita", :deprecated)
    )
    assert_equal(
      "__Amanita vaginata__ s __one__ v __two__ f __three__",
      Name.format_name("Amanita vaginata s one v two f three", :deprecated)
    )
  end

  def test_upper_word_pats
    pat = /^#{Name::UPPER_WORD}$/
    assert_no_match(pat, "")
    assert_no_match(pat, "A")
    assert_no_match(pat, "A-")
    assert_match(pat, "Ab")
    assert_match(pat, '"Ab"')
    assert_no_match(pat, '"Sp-ABC"')
    assert_no_match(pat, '"S01"')
    assert_no_match(pat, '"Abc\'')
    assert_no_match(pat, "'Abc'")
    assert_no_match(pat, '\'"Abc"')
    assert_match(pat, "Abc-def")
    assert_no_match(pat, "Abcdef-")
    assert_no_match(pat, "-Abcdef")
    assert_no_match(pat, "Abc1def")
    assert_no_match(pat, "AbcXdef")
    assert_match(pat, "Abcëdef")
  end

  def test_lower_word_pats
    pat = /^#{Name::LOWER_WORD}$/
    assert_no_match(pat, "")
    assert_no_match(pat, "a")
    assert_no_match(pat, "a-")
    assert_match(pat, "ab")
    assert_match(pat, '"ab"')
    assert_match(pat, '"sp-ABC"')
    assert_match(pat, '"sp-S01"')
    assert_match(pat, '"sp.S01"')
    assert_no_match(pat, '"sp. S01"')
    assert_no_match(pat, '"S01"')
    assert_no_match(pat, '"abc\'')
    assert_no_match(pat, "'abc'")
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
    pat = Name::AUTHOR_PAT
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

  def test_genus_or_up_pat
    @pat = "GENUS_OR_UP_PAT"
    pat = Name::GENUS_OR_UP_PAT
    assert_name_match_author_optional(pat, "Amanita")
    assert_name_match_author_optional(pat, "Amanita sp.", "Amanita")
    assert_name_match_author_optional(pat, '"Amanita"')
    assert_name_match_author_optional(pat, '"Amanita" sp.', '"Amanita"')
    assert_name_match_author_optional(pat, "Fossil-Okay")
    assert_name_match_author_optional(pat, "Fossil-Okay sp.", "Fossil-Okay")
    assert_no_match(pat, "Anythingelse-Bad")
  end

  def test_subgenus_pat
    @pat = "SUBGENUS_PAT"
    pat = Name::SUBGENUS_PAT
    assert_name_match_author_optional(pat, "Amanita subgenus Vaginatae")
    assert_name_match_author_optional(pat, "Amanita Subg. Vaginatae")
    assert_name_match_author_optional(pat, "Amanita subg Vaginatae")
    assert_name_match_author_optional(pat, '"Amanita subg. Vaginatae"')
  end

  def test_section_pat
    @pat = "SECTION_PAT"
    pat = Name::SECTION_PAT
    assert_name_match_author_optional(pat, "Amanita section Vaginatae")
    assert_name_match_author_optional(pat, "Amanita Sect. Vaginatae")
    assert_name_match_author_optional(pat, "Amanita sect Vaginatae")
    assert_name_match_author_optional(pat,
                                      "Amanita subg. Vaginatae sect. Vaginatae")
    assert_name_match_author_optional(pat, '"Amanita sect. Vaginatae"')
  end

  def test_subsection_pat
    @pat = "SUBSECTION_PAT"
    pat = Name::SUBSECTION_PAT
    assert_name_match_author_optional(pat, "Amanita subsection Vaginatae")
    assert_name_match_author_optional(pat, "Amanita SubSect. Vaginatae")
    assert_name_match_author_optional(pat, "Amanita subsect Vaginatae")
    assert_name_match_author_optional(
      pat, "Amanita subg. Vaginatae subsect. Vaginatae"
    )
    assert_name_match_author_optional(pat, '"Amanita subsect. Vaginatae"')
  end

  def test_stirps_pat
    @pat = "STIRPS_PAT"
    pat = Name::STIRPS_PAT
    assert_name_match_author_optional(pat, "Amanita stirps Vaginatae")
    assert_name_match_author_optional(pat, "Amanita Stirps Vaginatae")
    assert_name_match_author_optional(
      pat, "Amanita subg. Vaginatae sect. Vaginatae stirps Vaginatae"
    )
    assert_name_match_author_optional(
      pat, "Amanita subg. Vaginatae sect. Vaginatae subsect. Vaginatae " \
           "stirps Vaginatae"
    )
    assert_name_match_author_optional(pat, '"Amanita stirps Vaginatae"')
  end

  def test_species_pat
    @pat = "SPECIES_PAT"
    pat = Name::SPECIES_PAT
    assert_name_match_author_optional(pat, "Amanita vaginata")
    assert_name_match_author_optional(pat, 'Amanita "vaginata"')
    assert_name_match_author_optional(pat, "Amanita vag-inata")
    assert_name_match_author_optional(pat, "Amanita vaginëta")
    assert_name_match_author_optional(pat, 'Amanita "sp-S01"')
    assert_name_match_author_optional(pat, '"Amanita vaginata"')
  end

  def test_subspecies_pat
    @pat = "SUBSPECIES_PAT"
    pat = Name::SUBSPECIES_PAT
    assert_name_match_author_optional(pat, "Amanita vaginata subspecies grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata subsp grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata Subsp grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata subsp. grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata SSP grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata Ssp grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata ssp grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata ssp. grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata S grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata s grisea")
    assert_name_match_author_optional(pat, 'Amanita "sp-1" s. "ssp-1"')
    assert_name_match_author_optional(pat, '"Amanita vaginata ssp. grisea"')
  end

  def test_variety_pat
    @pat = "VARIETY_PAT"
    pat = Name::VARIETY_PAT
    assert_name_match_author_optional(pat, "Amanita vaginata variety grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata var grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata v grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata var. grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata v. grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata VAR grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata V grisea")
    assert_name_match_author_optional(
      pat, "Amanita vaginata ssp. grisea var. grisea"
    )
    assert_name_match_author_optional(
      pat, 'Amanita "sp-1" ssp. "ssp-1" var. "v-1"'
    )
    assert_name_match_author_optional(pat, '"Amanita vaginata var. grisea"')
  end

  def test_form_pat
    @pat = "FORM_PAT"
    pat = Name::FORM_PAT
    assert_name_match_author_optional(pat, "Amanita vaginata forma grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata form grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata f grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata form. grisea")
    assert_name_match_author_optional(pat, "Amanita vaginata f. grisea")
    assert_name_match_author_optional(
      pat, "Amanita vaginata ssp. grisea f. grisea"
    )
    assert_name_match_author_optional(
      pat, "Amanita vaginata var. grisea f. grisea"
    )
    assert_name_match_author_optional(
      pat, "Amanita vaginata ssp. grisea var. grisea f. grisea"
    )
    assert_name_match_author_optional(
      pat, 'Amanita "sp-1" ssp. "ssp-1" var. "v-1" f. "f-1"'
    )
    assert_name_match_author_optional(pat, '"Amanita vaginata f. grisea"')
  end

  def test_group_pat
    @pat = "GROUP_PAT"
    pat = Name::GROUP_PAT
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
      display_name: "**__Lecania ryaniana__** van den Boom",
      parent_name: "Lecania",
      rank: :Species,
      author: "van den Boom"
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
      rank: :Genus,
      author: "van den Boom"
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
      display_name: "**__Lecania ryaniana__** de Hoog",
      parent_name: "Lecania",
      rank: :Species,
      author: "de Hoog"
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
      rank: :Genus,
      author: "de Hoog"
    )
  end

  def test_name_parse_1d
    do_name_parse_test(
      "Synchytrium subgenus Endochytrium du Plessis",
      text_name: "Synchytrium subgenus Endochytrium",
      real_text_name: "Synchytrium subgenus Endochytrium",
      search_name: "Synchytrium subgenus Endochytrium du Plessis",
      real_search_name: "Synchytrium subgenus Endochytrium du Plessis",
      sort_name: "Synchytrium  {1subgenus  Endochytrium  du Plessis",
      display_name: "**__Synchytrium__** subgenus **__Endochytrium__** du Plessis", # rubocop:disable Layout/LineLength
      parent_name: "Synchytrium",
      rank: :Subgenus,
      author: "du Plessis"
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
      display_name: "**__Lecidea sanguineoatra__** sensu Nyl",
      parent_name: "Lecidea",
      rank: :Species,
      author: "sensu Nyl"
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
      display_name: "**__Acarospora squamulosa__** sensu Th. Fr.",
      parent_name: "Acarospora",
      rank: :Species,
      author: "sensu Th. Fr."
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
        "**__Cladina portentosa__** subsp. **__pacifica__** " \
        "f. **__decolorans__** auct.",
      parent_name: "Cladina portentosa subsp. pacifica",
      rank: :Form,
      author: "auct."
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
      display_name: "**__Japewia tornoënsis__** Somloë",
      parent_name: "Japewia",
      rank: :Species,
      author: "Somloë"
    )
  end

  def test_name_parse_6
    do_name_parse_test(
      'Micarea globularis "(Ach. ex Nyl.) Hedl."',
      text_name: "Micarea globularis",
      real_text_name: "Micarea globularis",
      search_name: 'Micarea globularis "(Ach. ex Nyl.) Hedl."',
      real_search_name: 'Micarea globularis "(Ach. ex Nyl.) Hedl."',
      sort_name: 'Micarea globularis  (Ach. ex Nyl.) Hedl."',
      display_name: '**__Micarea globularis__** "(Ach. ex Nyl.) Hedl."',
      parent_name: "Micarea",
      rank: :Species,
      author: '"(Ach. ex Nyl.) Hedl."'
    )
  end

  def test_name_parse_7
    do_name_parse_test(
      'Synechoblastus aggregatus ("Ach.") Th. Fr.',
      text_name: "Synechoblastus aggregatus",
      real_text_name: "Synechoblastus aggregatus",
      search_name: 'Synechoblastus aggregatus ("Ach.") Th. Fr.',
      real_search_name: 'Synechoblastus aggregatus ("Ach.") Th. Fr.',
      sort_name: 'Synechoblastus aggregatus  (Ach.") Th. Fr.',
      display_name: '**__Synechoblastus aggregatus__** ("Ach.") Th. Fr.',
      parent_name: "Synechoblastus",
      rank: :Species,
      author: '("Ach.") Th. Fr.'
    )
  end

  def test_name_parse_8
    do_name_parse_test(
      '"Toninia"',
      text_name: '"Toninia"',
      real_text_name: '"Toninia"',
      search_name: '"Toninia"',
      real_search_name: '"Toninia"',
      sort_name: 'Toninia"',
      display_name: '**__"Toninia"__**',
      parent_name: nil,
      rank: :Genus,
      author: ""
    )
  end

  def test_name_parse_9
    do_name_parse_test(
      '"Toninia" sp.',
      text_name: '"Toninia"',
      real_text_name: '"Toninia"',
      search_name: '"Toninia"',
      real_search_name: '"Toninia"',
      sort_name: 'Toninia"',
      display_name: '**__"Toninia"__**',
      parent_name: nil,
      rank: :Genus,
      author: ""
    )
  end

  def test_name_parse_10
    do_name_parse_test(
      '"Toninia" squalescens',
      text_name: '"Toninia" squalescens',
      real_text_name: '"Toninia" squalescens',
      search_name: '"Toninia" squalescens',
      real_search_name: '"Toninia" squalescens',
      sort_name: 'Toninia" squalescens',
      display_name: '**__"Toninia" squalescens__**',
      parent_name: '"Toninia"',
      rank: :Species,
      author: ""
    )
  end

  def test_name_parse_11
    do_name_parse_test(
      'Anaptychia "leucomelaena" auct.',
      text_name: 'Anaptychia "leucomelaena"',
      real_text_name: 'Anaptychia "leucomelaena"',
      search_name: 'Anaptychia "leucomelaena" auct.',
      real_search_name: 'Anaptychia "leucomelaena" auct.',
      sort_name: 'Anaptychia leucomelaena"  auct.',
      display_name: '**__Anaptychia "leucomelaena"__** auct.',
      parent_name: "Anaptychia",
      rank: :Species,
      author: "auct."
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
      rank: :Genus,
      author: ""
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
      rank: :Genus,
      author: ""
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
      rank: :Genus,
      author: ""
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
      rank: :Genus,
      author: "Nyl. ex Forss."
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
      rank: :Genus,
      author: "Nyl. ex Forss."
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
      rank: :Genus,
      author: "Nyl. ex Forss."
    )
  end

  def test_name_parse_18
    do_name_parse_test(
      "Japewia tornoënsis var. tornoënsis",
      text_name: "Japewia tornoensis var. tornoensis",
      real_text_name: "Japewia tornoënsis var. tornoënsis",
      search_name: "Japewia tornoensis var. tornoensis",
      real_search_name: "Japewia tornoënsis var. tornoënsis",
      sort_name: "Japewia tornoensis  {6var.  !tornoensis",
      display_name: "**__Japewia tornoënsis__** var. **__tornoënsis__**",
      parent_name: "Japewia tornoënsis",
      rank: :Variety,
      author: ""
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
      display_name: "**__Does this__** subsp. **__ever__** " \
                    "var. **__happen__** f. **__for__** Real?",
      parent_name: "Does this subsp. ever var. happen",
      rank: :Form,
      author: "Real?"
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
      display_name: "**__Boletus rex-veris__** Arora & Simonini",
      parent_name: "Boletus",
      rank: :Species,
      author: "Arora & Simonini"
    )
  end

  def test_name_parse_21
    do_name_parse_test(
      "Amanita “quoted”",
      text_name: 'Amanita "quoted"',
      real_text_name: 'Amanita "quoted"',
      search_name: 'Amanita "quoted"',
      real_search_name: 'Amanita "quoted"',
      sort_name: 'Amanita quoted"',
      display_name: '**__Amanita "quoted"__**',
      parent_name: "Amanita",
      rank: :Species,
      author: ""
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
      rank: :Genus,
      author: ""
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
      rank: :Section,
      author: "(L.) Ach."
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
      rank: :Stirps,
      author: "Ach. & Fr."
    )
  end

  def test_name_parse_26
    do_name_parse_test(
      "Amanita subgenus Vaginatae stirps Vaginatae",
      text_name: "Amanita subgenus Vaginatae stirps Vaginatae",
      real_text_name: "Amanita subgenus Vaginatae stirps Vaginatae",
      search_name: "Amanita subgenus Vaginatae stirps Vaginatae",
      real_search_name: "Amanita subgenus Vaginatae stirps Vaginatae",
      sort_name: "Amanita  {1subgenus  Vaginatae  {4stirps  !Vaginatae",
      display_name:
        "**__Amanita__** subgenus **__Vaginatae__** stirps **__Vaginatae__**",
      parent_name: "Amanita subgenus Vaginatae",
      rank: :Stirps,
      author: ""
    )
  end

  def test_name_parse_27
    do_name_parse_test(
      'Amanita "sp-S01"',
      text_name: 'Amanita "sp-S01"',
      real_text_name: 'Amanita "sp-S01"',
      search_name: 'Amanita "sp-S01"',
      real_search_name: 'Amanita "sp-S01"',
      sort_name: 'Amanita {sp-S01"',
      display_name: '**__Amanita "sp-S01"__**',
      parent_name: "Amanita",
      rank: :Species,
      author: ""
    )
  end

  def test_name_parse_28
    do_name_parse_test(
      'Amanita "sp-S01" Tulloss',
      text_name: 'Amanita "sp-S01"',
      real_text_name: 'Amanita "sp-S01"',
      search_name: 'Amanita "sp-S01" Tulloss',
      real_search_name: 'Amanita "sp-S01" Tulloss',
      sort_name: 'Amanita {sp-S01"  Tulloss',
      display_name: '**__Amanita "sp-S01"__** Tulloss',
      parent_name: "Amanita",
      rank: :Species,
      author: "Tulloss"
    )
  end

  def test_name_parse_29
    do_name_parse_test(
      'Amanita "Wrong Author"',
      text_name: "Amanita",
      real_text_name: "Amanita",
      search_name: 'Amanita "Wrong Author"',
      real_search_name: 'Amanita "Wrong Author"',
      sort_name: 'Amanita  Wrong Author"',
      display_name: '**__Amanita__** "Wrong Author"',
      parent_name: nil,
      rank: :Genus,
      author: '"Wrong Author"'
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
      display_name: "**__Amanita vaginata__**",
      parent_name: "Amanita",
      rank: :Species,
      author: ""
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
        "**__Pleurotus djamor__** (Fr.) Boedijn var. **__djamor__**",
      parent_name: "Pleurotus djamor",
      rank: :Variety,
      author: "(Fr.) Boedijn"
    )
  end

  def test_name_parse_33
    do_name_parse_test(
      "Pleurotus sp. T44 Tulloss",
      text_name: 'Pleurotus "sp-T44"',
      real_text_name: 'Pleurotus "sp-T44"',
      search_name: 'Pleurotus "sp-T44" Tulloss',
      real_search_name: 'Pleurotus "sp-T44" Tulloss',
      sort_name: 'Pleurotus {sp-T44"  Tulloss',
      display_name: '**__Pleurotus "sp-T44"__** Tulloss',
      parent_name: "Pleurotus",
      rank: :Species,
      author: "Tulloss"
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
      rank: :Genus,
      author: ""
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
      rank: :Section,
      author: "Pers."
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
      rank: :Section,
      author: "Pers."
    )
  end

  def test_name_parse_37
    do_name_parse_test(
      "Amanita subg. Amidella Singer sect. Amidella stirps Amidella",
      text_name: "Amanita subgenus Amidella sect. Amidella stirps Amidella",
      real_text_name:
        "Amanita subgenus Amidella sect. Amidella stirps Amidella",
      search_name:
        "Amanita subgenus Amidella sect. Amidella stirps Amidella Singer",
      real_search_name:
        "Amanita subgenus Amidella Singer sect. Amidella stirps Amidella",
      sort_name:
        "Amanita  {1subgenus  Amidella  {2sect.  !Amidella  {4stirps  " \
        "!Amidella  Singer",
      display_name:
        "**__Amanita__** subgenus **__Amidella__** Singer " \
        "sect. **__Amidella__** stirps **__Amidella__**",
      parent_name: "Amanita subgenus Amidella sect. Amidella",
      rank: :Stirps,
      author: "Singer"
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
      rank: :Family,
      author: "sensu Reid"
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
      rank: :Class,
      author: ""
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
      rank: :Phylum,
      author: ""
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
      display_name: "**__Armillaria mellea__** D.C.",
      parent_name: "Armillaria",
      rank: :Species,
      author: "D.C."
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
      display_name: "**__Sebacina schweinitzii__** comb. prov.",
      parent_name: "Sebacina",
      rank: :Species,
      author: "comb. prov."
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
      rank: :Group,
      author: ""
    )
    do_name_parse_test( # binomial, no author
      "Agaricus campestris group",
      text_name: "Agaricus campestris group",
      real_text_name: "Agaricus campestris group",
      search_name: "Agaricus campestris group",
      real_search_name: "Agaricus campestris group",
      sort_name: "Agaricus campestris   group",
      display_name: "**__Agaricus campestris__** group",
      parent_name: "Agaricus",
      rank: :Group,
      author: ""
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
      rank: :Group,
      author: "Author"
    )
    do_name_parse_test( # binomial, author
      "Agaricus campestris group Author",
      text_name: "Agaricus campestris group",
      real_text_name: "Agaricus campestris group",
      search_name: "Agaricus campestris group Author",
      real_search_name: "Agaricus campestris group Author",
      sort_name: "Agaricus campestris   group  Author",
      display_name: "**__Agaricus campestris__** group Author",
      parent_name: "Agaricus",
      rank: :Group,
      author: "Author"
    )
    do_name_parse_test( # binomial with author, "group" at end
      "Agaricus campestris Author group",
      text_name: "Agaricus campestris group",
      real_text_name: "Agaricus campestris group",
      search_name: "Agaricus campestris group Author",
      real_search_name: "Agaricus campestris group Author",
      sort_name: "Agaricus campestris   group  Author",
      display_name: "**__Agaricus campestris__** group Author",
      parent_name: "Agaricus",
      rank: :Group,
      author: "Author"
    )
    do_name_parse_test( # binomial, sensu author
      "Agaricus campestris group sensu Author",
      text_name: "Agaricus campestris group",
      real_text_name: "Agaricus campestris group",
      search_name: "Agaricus campestris group sensu Author",
      real_search_name: "Agaricus campestris group sensu Author",
      sort_name: "Agaricus campestris   group  sensu Author",
      display_name: "**__Agaricus campestris__** group sensu Author",
      parent_name: "Agaricus",
      rank: :Group,
      author: "sensu Author"
    )
    do_name_parse_test( # species with Tulloss form of sp. nov.
      "Pleurotus sp. T44 group Tulloss",
      text_name: 'Pleurotus "sp-T44" group',
      real_text_name: 'Pleurotus "sp-T44" group',
      search_name: 'Pleurotus "sp-T44" group Tulloss',
      real_search_name: 'Pleurotus "sp-T44" group Tulloss',
      sort_name: 'Pleurotus {sp-T44"   group  Tulloss',
      display_name: '**__Pleurotus "sp-T44"__** group Tulloss',
      parent_name: "Pleurotus",
      rank: :Group,
      author: "Tulloss"
    )
    do_name_parse_test( # subgenus group, with author
      "Amanita subg. Vaginatae group (L.) Ach.",
      text_name: "Amanita subgenus Vaginatae group",
      real_text_name: "Amanita subgenus Vaginatae group",
      search_name: "Amanita subgenus Vaginatae group (L.) Ach.",
      real_search_name: "Amanita subgenus Vaginatae group (L.) Ach.",
      sort_name: "Amanita  {1subgenus  Vaginatae   group  (L.) Ach.",
      display_name:
        "**__Amanita__** subgenus **__Vaginatae__** group (L.) Ach.",
      parent_name: "Amanita",
      rank: :Group,
      author: "(L.) Ach."
    )
    do_name_parse_test( # stirps group, with sub-genus parent
      "Amanita subgenus Vaginatae stirps Vaginatae group",
      text_name: "Amanita subgenus Vaginatae stirps Vaginatae group",
      real_text_name: "Amanita subgenus Vaginatae stirps Vaginatae group",
      search_name: "Amanita subgenus Vaginatae stirps Vaginatae group",
      real_search_name: "Amanita subgenus Vaginatae stirps Vaginatae group",
      sort_name:
        "Amanita  {1subgenus  Vaginatae  {4stirps  !Vaginatae   group",
      display_name:
        "**__Amanita__** subgenus **__Vaginatae__** stirps " \
        "**__Vaginatae__** group",
      parent_name: "Amanita subgenus Vaginatae",
      rank: :Group,
      author: ""
    )
    do_name_parse_test( # binomial, "group" part of epithet
      "Agaricus grouperi group Author",
      text_name: "Agaricus grouperi group",
      real_text_name: "Agaricus grouperi group",
      search_name: "Agaricus grouperi group Author",
      real_search_name: "Agaricus grouperi group Author",
      sort_name: "Agaricus grouperi   group  Author",
      display_name: "**__Agaricus grouperi__** group Author",
      parent_name: "Agaricus",
      rank: :Group,
      author: "Author"
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
      rank: :Group,
      author: "Agaricus"
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
      rank: :Group,
      author: ""
    )
    do_name_parse_test( # binomial, no author
      "Agaricus campestris clade",
      text_name: "Agaricus campestris clade",
      real_text_name: "Agaricus campestris clade",
      search_name: "Agaricus campestris clade",
      real_search_name: "Agaricus campestris clade",
      sort_name: "Agaricus campestris   clade",
      display_name: "**__Agaricus campestris__** clade",
      parent_name: "Agaricus",
      rank: :Group,
      author: ""
    )
    do_name_parse_test( # binomial, sensu author
      "Agaricus campestris clade sensu Author",
      text_name: "Agaricus campestris clade",
      real_text_name: "Agaricus campestris clade",
      search_name: "Agaricus campestris clade sensu Author",
      real_search_name: "Agaricus campestris clade sensu Author",
      sort_name: "Agaricus campestris   clade  sensu Author",
      display_name: "**__Agaricus campestris__** clade sensu Author",
      parent_name: "Agaricus",
      rank: :Group,
      author: "sensu Author"
    )
    do_name_parse_test( # binomial with author, "clade" at end
      "Agaricus campestris Author clade",
      text_name: "Agaricus campestris clade",
      real_text_name: "Agaricus campestris clade",
      search_name: "Agaricus campestris clade Author",
      real_search_name: "Agaricus campestris clade Author",
      sort_name: "Agaricus campestris   clade  Author",
      display_name: "**__Agaricus campestris__** clade Author",
      parent_name: "Agaricus",
      rank: :Group,
      author: "Author"
    )
  end

  def test_name_parse_deprecated
    do_name_parse_test(
      "Lecania ryaniana van den Boom",
      {
        text_name: "Lecania ryaniana",
        real_text_name: "Lecania ryaniana",
        search_name: "Lecania ryaniana van den Boom",
        real_search_name: "Lecania ryaniana van den Boom",
        sort_name: "Lecania ryaniana  van den Boom",
        display_name: "__Lecania ryaniana__ van den Boom",
        parent_name: "Lecania",
        rank: :Species,
        author: "van den Boom"
      },
      deprecated: true
    )
    do_name_parse_test( # binomial, no author, deprecated
      "Agaricus campestris group",
      {
        text_name: "Agaricus campestris group",
        real_text_name: "Agaricus campestris group",
        search_name: "Agaricus campestris group",
        real_search_name: "Agaricus campestris group",
        sort_name: "Agaricus campestris   group",
        display_name: "__Agaricus campestris__ group",
        parent_name: "Agaricus",
        rank: :Group,
        author: ""
      },
      deprecated: true
    )
    do_name_parse_test( # binomial, sensu author, deprecated
      "Agaricus campestris group sensu Author",
      {
        text_name: "Agaricus campestris group",
        real_text_name: "Agaricus campestris group",
        search_name: "Agaricus campestris group sensu Author",
        real_search_name: "Agaricus campestris group sensu Author",
        sort_name: "Agaricus campestris   group  sensu Author",
        display_name: "__Agaricus campestris__ group sensu Author",
        parent_name: "Agaricus",
        rank: :Group,
        author: "sensu Author"
      },
      deprecated: true
    )
  end

  # -----------------------------
  #  Test classification.
  # -----------------------------

  def test_parse_classification_1
    do_parse_classification_test("Kingdom: Fungi", [[:Kingdom, "Fungi"]])
  end

  def test_parse_classification_2
    do_parse_classification_test(%(Kingdom: Fungi\r
      Phylum: Basidiomycota\r
      Class: Basidiomycetes\r
      Order: Agaricales\r
      Family: Amanitaceae),
                                 [[:Kingdom, "Fungi"],
                                  [:Phylum, "Basidiomycota"],
                                  [:Class, "Basidiomycetes"],
                                  [:Order, "Agaricales"],
                                  [:Family, "Amanitaceae"]])
  end

  def test_parse_classification_3
    do_parse_classification_test(%(Kingdom: Fungi\r
      \r
      Family: Amanitaceae),
                                 [[:Kingdom, "Fungi"],
                                  [:Family, "Amanitaceae"]])
  end

  def test_parse_classification_4
    do_parse_classification_test(%(Kingdom: _Fungi_\r
      Family: _Amanitaceae_),
                                 [[:Kingdom, "Fungi"],
                                  [:Family, "Amanitaceae"]])
  end

  def test_parse_classification_5
    do_parse_classification_test("Queendom: Fungi", [[:Queendom, "Fungi"]])
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
      :Species, "Kingdom: Fungi", "Kingdom: _Fungi_"
    )
  end

  def test_validate_classification_2
    do_validate_classification_test(
      :Species,
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
    do_validate_classification_test(:Species, %(Kingdom: Fungi\r
      \r
      Family: Amanitaceae),
                                    "Kingdom: _Fungi_\r\nFamily: _Amanitaceae_")
  end

  def test_validate_classification_4
    do_validate_classification_test(:Species, %(Kingdom: _Fungi_\r
      Family: _Amanitaceae_),
                                    "Kingdom: _Fungi_\r\nFamily: _Amanitaceae_")
  end

  def test_validate_classification_5
    do_validate_classification_test(:Species, "Queendom: Fungi", false)
  end

  def test_validate_classification_6
    do_validate_classification_test(:Species, "Junk text", false)
  end

  def test_validate_classification_7
    do_validate_classification_test(:Genus, "Species: calyptroderma", false)
  end

  def test_validate_classification_8
    do_validate_classification_test(
      :Species, "Family: Amanitaceae", "Family: _Amanitaceae_"
    )
  end

  def test_validate_classification_9
    do_validate_classification_test(:Queendom, "Family: Amanitaceae", false)
  end

  def test_validate_classification_10
    do_validate_classification_test(:Species, "", "")
  end

  def test_validate_classification_11
    do_validate_classification_test(:Species, nil, nil)
  end

  def test_validate_classification_12
    do_validate_classification_test(:Genus, "Family: _Agaricales_", false)
  end

  def test_validate_classification_13
    do_validate_classification_test(:Genus, "Kingdom: _Agaricales_", false)
  end

  def test_validate_classification_14
    do_validate_classification_test(
      :Genus, "Kingdom: _Blubber_", "Kingdom: _Blubber_"
    )
  end

  def test_validate_classification_15
    do_validate_classification_test(
      :Genus, "Kingdom: _Fungi_\nOrder: _Insecta_", false
    )
    do_validate_classification_test(
      :Genus, "Kingdom: _Animalia_\nOrder: _Insecta_",
      "Kingdom: _Animalia_\r\nOrder: _Insecta_"
    )
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

  def test_text_before_rank
    name_above_genus = names(:fungi)
    assert_equal("Fungi", name_above_genus.text_before_rank)

    name_between_genus_and_species = names(:amanita_subgenus_lepidella)
    assert_equal("Amanita", name_between_genus_and_species.text_before_rank)

    variety_name = names(:amanita_boudieri_var_beillei)
    assert_equal("Amanita boudieri var. beillei", variety_name.text_before_rank)
  end

  # ------------------------------
  #  Test ancestors and parents.
  # ------------------------------

  def test_ancestors_1
    assert_name_list_equal([names(:agaricus),
                            names(:agaricaceae),
                            names(:agaricales),
                            names(:basidiomycetes),
                            names(:basidiomycota),
                            names(:fungi)],
                           names(:agaricus_campestris).all_parents)
    assert_name_list_equal(
      [names(:agaricus)], names(:agaricus_campestris).parents
    )
    assert_name_list_equal(
      [names(:agaricaceae)], names(:agaricus).parents
    )
    assert_name_list_equal(
      [], names(:agaricus_campestris).children
    )
    assert_name_list_equal([names(:agaricus_campestras),
                            names(:agaricus_campestris),
                            names(:agaricus_campestros),
                            names(:agaricus_campestrus)],
                           names(:agaricus).children, :sort)
  end

  def test_ancestors_2
    # use Petigera instead of Peltigera because it has no classification string
    p = names(:petigera)
    assert_name_list_equal([], p.all_parents)
    assert_name_list_equal([], p.children)

    pc   = create_test_name("Petigera canina (L.) Willd.")
    pcr  = create_test_name("Petigera canina var. rufescens (Weiss) Mudd")
    pcri = create_test_name(
      "Petigera canina var. rufescens f. innovans (Körber) J. W. Thomson"
    )
    pcs  = create_test_name("Petigera canina var. spuria (Ach.) Schaerer")

    pa   = create_test_name("Petigera aphthosa (L.) Willd.")
    pac  = create_test_name("Petigera aphthosa f. complicata (Th. Fr.) Zahlbr.")
    pav  = create_test_name("Petigera aphthosa var. variolosa A. Massal.")

    pp   = create_test_name("Petigera polydactylon (Necker) Hoffm")
    pp2  = create_test_name("Petigera polydactylon (Bogus) Author")
    pph  = create_test_name("Petigera polydactylon var. hymenina (Ach.) Flotow")
    ppn  = create_test_name("Petigera polydactylon var. neopolydactyla Gyelnik")

    assert_name_list_equal([pa, pc, pp, pp2], p.children, :sort)
    assert_name_list_equal([pcr, pcs], pc.children, :sort)
    assert_name_list_equal([pcri], pcr.children, :sort)
    assert_name_list_equal([pav], pa.children, :sort)
    assert_name_list_equal([pph, ppn], pp.children, :sort)

    # Oops! Petigera is misspelled, so these aren't right...
    assert_name_list_equal([], pc.all_parents)
    assert_name_list_equal([pc], pcr.all_parents)
    assert_name_list_equal([pcr, pc], pcri.all_parents)
    assert_name_list_equal([pc], pcs.all_parents)
    assert_name_list_equal([], pa.all_parents)
    assert_name_list_equal([pa], pac.all_parents)
    assert_name_list_equal([pa], pav.all_parents)
    assert_name_list_equal([], pp.all_parents)
    assert_name_list_equal([], pp2.all_parents)
    assert_name_list_equal([pp], pph.all_parents)
    assert_name_list_equal([pp], ppn.all_parents)

    assert_name_list_equal([], pc.parents)
    assert_name_list_equal([pc], pcr.parents)
    assert_name_list_equal([pcr], pcri.parents)
    assert_name_list_equal([pc], pcs.parents)
    assert_name_list_equal([], pa.parents)
    assert_name_list_equal([pa], pac.parents)
    assert_name_list_equal([pa], pav.parents)
    assert_name_list_equal([], pp.parents)
    assert_name_list_equal([pp], pph.parents)
    assert_name_list_equal([pp], ppn.parents)

    # Try it again if we clear the misspelling flag.  (Still deprecated though.)
    p.correct_spelling = nil
    p.save

    assert_name_list_equal([p], pc.all_parents, :sort)
    assert_name_list_equal([pc], pcr.all_parents, :sort)
    assert_name_list_equal([pcr, pc], pcri.all_parents, :sort)
    assert_name_list_equal([pc], pcs.all_parents, :sort)
    assert_name_list_equal([p], pa.all_parents, :sort)
    assert_name_list_equal([pa], pac.all_parents, :sort)
    assert_name_list_equal([pa], pav.all_parents, :sort)
    assert_name_list_equal([p], pp.all_parents, :sort)
    assert_name_list_equal([p], pp2.all_parents, :sort)
    assert_name_list_equal([pp], pph.all_parents, :sort)
    assert_name_list_equal([pp], ppn.all_parents, :sort)

    assert_name_list_equal([p], pc.parents)
    assert_name_list_equal([pc], pcr.parents)
    assert_name_list_equal([pcr], pcri.parents)
    assert_name_list_equal([pc], pcs.parents)
    assert_name_list_equal([p], pa.parents)
    assert_name_list_equal([pa], pac.parents)
    assert_name_list_equal([pa], pav.parents)
    assert_name_list_equal([p], pp.parents)
    assert_name_list_equal([pp], pph.parents, :sort)
    assert_name_list_equal([pp], ppn.parents, :sort)

    pp2.change_deprecated(true)
    pp2.save

    assert_name_list_equal([pa, pc, pp, pp2], p.children, :sort)
    assert_name_list_equal([pp], pph.all_parents, :sort)
    assert_name_list_equal([pp], ppn.all_parents, :sort)
    assert_name_list_equal([pp], pph.parents, :sort)
    assert_name_list_equal([pp], ppn.parents, :sort)

    pp.change_deprecated(true)
    pp.save

    assert_name_list_equal([pa, pc, pp, pp2], p.children, :sort)
    assert_name_list_equal([pp, p], pph.all_parents, :sort)
    assert_name_list_equal([pp, p], ppn.all_parents, :sort)
    assert_name_list_equal([pp], pph.parents, :sort)
    assert_name_list_equal([pp], ppn.parents, :sort)
  end

  def test_ancestors_3
    # Make sure only Ascomycetes through Peltigera have
    # Ascomycota in their classification at first.
    assert_equal(4, Name.where("classification LIKE '%Ascomycota%'").count)

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

    assert_name_list_equal([], kng.all_parents)
    assert_name_list_equal([kng], phy.all_parents)
    assert_name_list_equal([phy, kng], cls.all_parents)
    assert_name_list_equal([cls, phy, kng], ord.all_parents)
    assert_name_list_equal([ord, cls, phy, kng], fam.all_parents)
    assert_name_list_equal([fam, ord, cls, phy, kng], gen.all_parents)
    assert_name_list_equal([gen, fam, ord, cls, phy, kng], spc.all_parents)
    assert_name_list_equal([spc, gen, fam, ord, cls, phy, kng], ssp.all_parents)
    assert_name_list_equal([ssp, spc, gen, fam, ord, cls, phy, kng],
                           var.all_parents)
    assert_name_list_equal([var, ssp, spc, gen, fam, ord, cls, phy, kng],
                           frm.all_parents)

    assert_name_list_equal([],    kng.parents)
    assert_name_list_equal([kng], phy.parents)
    assert_name_list_equal([phy], cls.parents)
    assert_name_list_equal([cls], ord.parents)
    assert_name_list_equal([ord], fam.parents)
    assert_name_list_equal([fam], gen.parents)
    assert_name_list_equal([gen], spc.parents)
    assert_name_list_equal([spc], ssp.parents)
    assert_name_list_equal([ssp], var.parents)
    assert_name_list_equal([var], frm.parents)

    assert(kng.children.include?(phy))
    assert_name_list_equal([cls], phy.children)
    assert_name_list_equal([ord], cls.children)
    assert_name_list_equal([fam], ord.children)
    assert_name_list_equal([gen], fam.children)
    assert_name_list_equal([spc], gen.children)
    assert_name_list_equal([ssp], spc.children)
    assert_name_list_equal([var], ssp.children)
    assert_name_list_equal([frm], var.children)
    assert_name_list_equal([],    frm.children)

    assert_empty([phy, cls, ord, fam, gen, spc, ssp, var, frm] -
                 kng.all_children)
    assert_name_list_equal([cls, ord, fam, gen, spc, ssp, var, frm],
                           phy.all_children, :sort)
    assert_name_list_equal([ord, fam, gen, spc, ssp, var, frm],
                           cls.all_children, :sort)
    assert_name_list_equal([fam, gen, spc, ssp, var, frm],
                           ord.all_children, :sort)
    assert_name_list_equal([gen, spc, ssp, var, frm], fam.all_children, :sort)
    assert_name_list_equal([spc, ssp, var, frm], gen.all_children, :sort)
    assert_name_list_equal([ssp, var, frm], spc.all_children, :sort)
    assert_name_list_equal([var, frm], ssp.all_children, :sort)
    assert_name_list_equal([frm], var.all_children, :sort)
    assert_name_list_equal([], frm.all_children, :sort)
  end

  # --------------------------------------
  #  Test email notification heuristics.
  # --------------------------------------

  def test_email_notification
    name = names(:peltigera)
    desc = name_descriptions(:peltigera_desc)

    rolf.email_names_admin    = false
    rolf.email_names_author   = true
    rolf.email_names_editor   = true
    rolf.email_names_reviewer = true
    rolf.email_names_all      = false
    rolf.save

    mary.email_names_admin    = false
    mary.email_names_author   = true
    mary.email_names_editor   = false
    mary.email_names_reviewer = false
    mary.email_names_all      = false
    mary.save

    dick.email_names_admin    = false
    dick.email_names_author   = false
    dick.email_names_editor   = false
    dick.email_names_reviewer = false
    dick.email_names_all      = false
    dick.save

    katrina.email_names_admin    = false
    katrina.email_names_author   = true
    katrina.email_names_editor   = true
    katrina.email_names_reviewer = true
    katrina.email_names_all      = true
    katrina.save

    # Start with no reviewers, editors or authors.
    User.current = nil
    desc.gen_desc = ""
    desc.review_status = :unreviewed
    desc.reviewer = nil
    Name.without_revision do
      desc.save
    end
    desc.authors.clear
    desc.editors.clear
    desc.reload
    name_version = name.version
    description_version = desc.version
    QueuedEmail.queue_emails(true)
    QueuedEmail.all.map(&:destroy)

    assert_equal(0, desc.authors.length)
    assert_equal(0, desc.editors.length)
    assert_nil(desc.reviewer_id)

    # email types:  author  editor  review  all     interest
    # 1 Rolf:       x       x       x       .       .
    # 2 Mary:       x       .       .       .       .
    # 3 Dick:       .       .       .       .       .
    # 4 Katrina:    x       x       x       x       .
    # Authors: --        editors: --         reviewer: -- (unreviewed)
    # Rolf erases notes: notify Katrina (all), Rolf becomes editor.
    User.current = rolf
    desc.reload
    desc.classification = ""
    desc.gen_desc = ""
    desc.diag_desc = ""
    desc.distribution = ""
    desc.habitat = ""
    desc.look_alikes = ""
    desc.uses = ""
    assert_equal(0, QueuedEmail.count)
    desc.save
    assert_equal(description_version + 1, desc.version)
    assert_equal(0, desc.authors.length)
    assert_equal(1, desc.editors.length)
    assert_nil(desc.reviewer_id)
    assert_equal(rolf, desc.editors.first)
    assert_equal(1, QueuedEmail.count)
    assert_email(0,
                 flavor: "QueuedEmail::NameChange",
                 from: rolf,
                 to: katrina,
                 name: name.id,
                 description: desc.id,
                 old_name_version: name.version,
                 new_name_version: name.version,
                 old_description_version: desc.version - 1,
                 new_description_version: desc.version,
                 review_status: "no_change")

    # Katrina wisely reconsiders requesting notifications of all name changes.
    katrina.email_names_all = false
    katrina.save

    # email types:  author  editor  review  all     interest
    # 1 Rolf:       x       x       x       .       .
    # 2 Mary:       x       .       .       .       .
    # 3 Dick:       .       .       .       .       .
    # 4 Katrina:    x       x       x       .       .
    # Authors: --        editors: Rolf       reviewer: -- (unreviewed)
    # Mary writes gen_desc: notify Rolf (editor), Mary becomes author.
    User.current = mary
    desc.reload
    desc.gen_desc = "Mary wrote this."
    desc.save
    assert_equal(description_version + 2, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(1, desc.editors.length)
    assert_nil(desc.reviewer_id)
    assert_equal(mary, desc.authors.first)
    assert_equal(rolf, desc.editors.first)
    assert_equal(2, QueuedEmail.count)
    assert_email(1,
                 flavor: "QueuedEmail::NameChange",
                 from: mary,
                 to: rolf,
                 name: name.id,
                 description: desc.id,
                 old_name_version: name.version,
                 new_name_version: name.version,
                 old_description_version: desc.version - 1,
                 new_description_version: desc.version,
                 review_status: "no_change")

    # Rolf doesn't want to be notified if people change names he's edited.
    rolf.email_names_editor = false
    rolf.save

    # email types:  author  editor  review  all     interest
    # 1 Rolf:       x       .       x       .       .
    # 2 Mary:       x       .       .       .       .
    # 3 Dick:       .       .       .       .       .
    # 4 Katrina:    x       x       x       .       .
    # Authors: Mary      editors: Rolf       reviewer: -- (unreviewed)
    # Dick changes uses: notify Mary (author); Dick becomes editor.
    User.current = dick
    desc.reload
    desc.uses = "Something more new."
    desc.save
    assert_equal(description_version + 3, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_nil(desc.reviewer_id)
    assert_equal(mary, desc.authors.first)
    assert_equal([rolf.id, dick.id].sort, desc.editors.map(&:id).sort)
    assert_equal(3, QueuedEmail.count)
    assert_email(2,
                 flavor: "QueuedEmail::NameChange",
                 from: dick,
                 to: mary,
                 name: name.id,
                 description: desc.id,
                 old_name_version: name.version,
                 new_name_version: name.version,
                 old_description_version: desc.version - 1,
                 new_description_version: desc.version,
                 review_status: "no_change")

    # Mary opts out of author emails, add Katrina as new author.
    desc.add_author(katrina)
    mary.email_names_author = false
    mary.save

    # email types:  author  editor  review  all     interest
    # 1 Rolf:       x       .       x       .       .
    # 2 Mary:       .       .       .       .       .
    # 3 Dick:       .       .       .       .       .
    # 4 Katrina:    x       x       x       .       .
    # Authors: Mary,Katrina   editors: Rolf,Dick   reviewer: -- (unreviewed)
    # Rolf reviews name: notify Katrina (author), Rolf becomes reviewer.
    User.current = rolf
    desc.reload
    desc.update_review_status(:inaccurate)
    assert_equal(description_version + 3, desc.version)
    assert_equal(2, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal(rolf.id, desc.reviewer_id)
    assert_equal([mary.id, katrina.id].sort, desc.authors.map(&:id).sort)
    assert_equal([rolf.id, dick.id].sort, desc.editors.map(&:id).sort)
    assert_equal(4, QueuedEmail.count)
    assert_email(3,
                 flavor: "QueuedEmail::NameChange",
                 from: rolf,
                 to: katrina,
                 name: name.id,
                 description: desc.id,
                 old_name_version: name.version,
                 new_name_version: name.version,
                 old_description_version: desc.version - 1,
                 new_description_version: desc.version,
                 review_status: "inaccurate")

    # Have Katrina express disinterest.
    Interest.create(target: name, user: katrina, state: false)

    # email types:  author  editor  review  all     interest
    # 1 Rolf:       x       .       x       .       .
    # 2 Mary:       .       .       .       .       .
    # 3 Dick:       .       .       .       .       .
    # 4 Katrina:    x       x       x       .       no
    # Authors: Mary,Katrina   editors: Rolf,Dick   reviewer: Rolf (inaccurate)
    # Dick changes look-alikes: notify Rolf (reviewer), clear review status
    User.current = dick
    desc.reload
    desc.look_alikes = "Dick added this -- it's suspect"
    # (This is exactly what is normally done by name controller in edit_name.
    # Yes, Dick isn't actually trying to review, and isn't even a reviewer.
    # The point is to update the review date if Dick *were*, or reset the
    # status to unreviewed in the present case that he *isn't*.)
    desc.update_review_status(:inaccurate)
    desc.save
    assert_equal(description_version + 4, desc.version)
    assert_equal(2, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal(:unreviewed, desc.review_status)
    assert_nil(desc.reviewer_id)
    assert_equal([mary.id, katrina.id].sort, desc.authors.map(&:id).sort)
    assert_equal([rolf.id, dick.id].sort, desc.editors.map(&:id).sort)
    assert_equal(5, QueuedEmail.count)
    assert_email(4,
                 flavor: "QueuedEmail::NameChange",
                 from: dick,
                 to: rolf,
                 name: name.id,
                 description: desc.id,
                 old_name_version: name.version,
                 new_name_version: name.version,
                 old_description_version: desc.version - 1,
                 new_description_version: desc.version,
                 review_status: "unreviewed")

    # Mary expresses interest.
    Interest.create(target: name, user: mary, state: true)

    # email types:  author  editor  review  all     interest
    # 1 Rolf:       x       .       x       .       .
    # 2 Mary:       .       .       .       .       yes
    # 3 Dick:       .       .       .       .       .
    # 4 Katrina:    x       x       x       .       no
    # Authors: Mary,Katrina   editors: Rolf,Dick   reviewer: Rolf (unreviewed)
    # Rolf changes 'uses': notify Mary (interest).
    User.current = rolf
    name.reload
    name.citation = "Rolf added this."
    name.save
    assert_equal(name_version + 1, name.version)
    assert_equal(description_version + 4, desc.version)
    assert_equal(2, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_nil(desc.reviewer_id)
    assert_equal([mary.id, katrina.id].sort, desc.authors.map(&:id).sort)
    assert_equal([rolf.id, dick.id].sort, desc.editors.map(&:id).sort)
    assert_equal(6, QueuedEmail.count)
    assert_email(5,
                 flavor: "QueuedEmail::NameChange",
                 from: rolf,
                 to: mary,
                 name: name.id,
                 description: 0,
                 old_name_version: name.version - 1,
                 new_name_version: name.version,
                 old_description_version: 0,
                 new_description_version: 0,
                 review_status: "no_change")
    QueuedEmail.queue_emails(false)
  end

  def test_misspelling
    User.current = rolf

    # Make sure deprecating a name doesn't clear misspelling stuff.
    names(:petigera).change_deprecated(true)
    assert(names(:petigera).is_misspelling?)
    assert_equal(names(:peltigera), names(:petigera).correct_spelling)

    # Make sure approving a name clears misspelling stuff.
    names(:petigera).change_deprecated(false)
    assert_not(names(:petigera).is_misspelling?)
    assert_nil(names(:petigera).correct_spelling)

    # Temporarily disabling the name primer.  See comments there.
    # # Coprinus comatus should normally end up in name primer.
    # if File.exist?(MO.name_primer_cache_file)
    #   File.delete(MO.name_primer_cache_file)
    # end
    # assert_not(Name.primer.select { |n| n == "Coprinus comatus" }.empty?)
    #
    # # Mark it as misspelled and see that it gets removed from the primer list.
    # names(:coprinus_comatus).correct_spelling = names(:agaricus_campestris)
    # names(:coprinus_comatus).change_deprecated(true)
    # names(:coprinus_comatus).save
    # File.delete(MO.name_primer_cache_file)
    # assert(Name.primer.select { |n| n == "Coprinus comatus" }.empty?)
  end

  def test_lichen
    assert(names(:tremella_mesenterica).is_lichen?)
    assert(names(:tremella).is_lichen?)
    assert(names(:tremella_justpublished).is_lichen?)
    assert_not(names(:agaricus_campestris).is_lichen?)
  end

  def test_has_eol_data
    assert(names(:peltigera).has_eol_data?)
    assert_not(names(:lactarius_alpigenes).has_eol_data?)
  end

  def test_hiding_authors
    dick.hide_authors = :above_species
    mary.hide_authors = :none

    name = names(:agaricus_campestris)
    User.current = mary
    assert_equal("**__Agaricus campestris__** L.", name.display_name)
    User.current = dick
    assert_equal("**__Agaricus campestris__** L.", name.display_name)

    name = names(:macrocybe_titans)
    User.current = mary
    assert_equal("**__Macrocybe__** Titans", name.display_name)
    User.current = dick
    assert_equal("**__Macrocybe__**", name.display_name)

    name.display_name = "__Macrocybe__ (Author) Author"
    assert_equal("__Macrocybe__", name.display_name)

    name.display_name = "__Macrocybe__ (van Helsing) Author"
    assert_equal("__Macrocybe__", name.display_name)

    name.display_name = "__Macrocybe__ sect. __Helsing__ Author"
    assert_equal("__Macrocybe__ sect. __Helsing__", name.display_name)

    name.display_name = "__Macrocybe__ sect. __Helsing__"
    assert_equal("__Macrocybe__ sect. __Helsing__", name.display_name)

    name.display_name = "**__Macrocybe__** (van Helsing) Author"
    assert_equal("**__Macrocybe__**", name.display_name)

    name.display_name = "**__Macrocybe__** sect. **__Helsing__** Author"
    assert_equal("**__Macrocybe__** sect. **__Helsing__**", name.display_name)

    name.display_name = "**__Macrocybe__** sect. **__Helsing__**"
    assert_equal("**__Macrocybe__** sect. **__Helsing__**", name.display_name)

    name.display_name = "**__Macrocybe__** subgenus **__Blah__**"
    assert_equal("**__Macrocybe__** subgenus **__Blah__**", name.display_name)
  end

  def test_changing_author_of_autonym
    name = create_test_name("Acarospora nodulosa var. nodulosa")
    assert_equal("Acarospora nodulosa var. nodulosa", name.text_name)
    assert_equal("Acarospora nodulosa var. nodulosa", name.search_name)
    assert_equal("Acarospora nodulosa  {6var.  !nodulosa", name.sort_name)
    assert_equal("**__Acarospora nodulosa__** var. **__nodulosa__**",
                 name.display_name)
    assert_equal("", name.author)

    name.change_author("(Dufour) Hue")
    assert_equal("Acarospora nodulosa var. nodulosa", name.text_name)
    assert_equal("Acarospora nodulosa var. nodulosa (Dufour) Hue",
                 name.search_name)
    assert_equal("Acarospora nodulosa  {6var.  !nodulosa  (Dufour) Hue",
                 name.sort_name)
    assert_equal(
      "**__Acarospora nodulosa__** (Dufour) Hue var. **__nodulosa__**",
      name.display_name
    )
    assert_equal("(Dufour) Hue", name.author)

    name.change_author("Ach.")
    assert_equal("Acarospora nodulosa var. nodulosa", name.text_name)
    assert_equal("Acarospora nodulosa var. nodulosa Ach.", name.search_name)
    assert_equal("Acarospora nodulosa  {6var.  !nodulosa  Ach.", name.sort_name)
    assert_equal("**__Acarospora nodulosa__** Ach. var. **__nodulosa__**",
                 name.display_name)
    assert_equal("Ach.", name.author)
  end

  # --------------------------------------
  #  Synonymy
  # --------------------------------------

  def test_synonym_ids
    # Although this test is coupled to synonym_ids' details
    # I can't find a better way to cover all the paths through that method

    # If a Name has synonym(s), then
    # synonym_ids will hit the db unless @synonyms exists, and vice versa
    name_with_other_synonyms = names(:chlorophyllum_rachodes)
    synonym = name_with_other_synonyms.synonym
    synonym_ids = Name.where(synonym: synonym).pluck(:id)

    # Prove that synonym_ids is correct when @synonyms doesn't exist
    assert_equal(synonym_ids, name_with_other_synonyms.synonym_ids)

    # Prove that synonym_ids is correct when @synonyms already exists
    # synonyms = name_with_other_synonyms
    assert_equal(
      name_with_other_synonyms.synonyms.map(&:id), # creates @synonyms
      name_with_other_synonyms.synonym_ids
    )

    # Prove that synonym_ids is correct when name lacks synonyms
    name_without_other_synonyms = names(:conocybe_filaris)
    assert_equal([name_without_other_synonyms.id],
                 name_without_other_synonyms.synonym_ids)
  end

  def test_other_approved_synonyms
    assert_equal([names(:chlorophyllum_rachodes)],
                 names(:chlorophyllum_rhacodes).other_approved_synonyms)
    assert_empty(names(:lactarius_alpinus).other_approved_synonyms)
  end

  def test_best_preferred_synonym
    # no preferred synonyms
    assert_empty(names(:pluteus_petasatus_deprecated).best_preferred_synonym)

    # only 1 preferred synonym
    assert_equal(names(:lactarius_alpinus),
                 names(:lactarius_alpigenes).best_preferred_synonym)

    # > 1 preferred synonym, none with observations
    # Macrolepiota rachodes & rhacodes are synonyms, approved, and have
    # no observations
    # Create a deprecated synonym and test it
    deprecated_name = Name.create!(
      text_name: "Lepiota rhacodes",
      author: "(Vittad.) Quél.",
      display_name: "__Lepiota rhacodes__ (Vittad.) Quél.",
      synonym: synonyms(:macrolepiota_rachodes_synonym),
      deprecated: true,
      rank: :Species, user: users(:rolf)
    )
    # M. rachodes & rhacodes are tied with 0 Observations
    # "Best" one is the one last updated
    assert_equal(names(:macrolepiota_rachodes),
                 deprecated_name.best_preferred_synonym)

    # > 1 preferred synonyms, one with observations
    # C. rachodes is approved, has 1 Observation
    # C. rachodes is approved, has 0 Observations
    # Create a deprecated synonym and test it
    deprecated_name = Name.create!(
      text_name: "Agaricus rhacodes",
      author: "Vittad.",
      display_name: "__Agaricus rhacodes__ Vittad.",
      synonym: synonyms(:chlorophyllum_rachodes_synonym),
      deprecated: true,
      rank: :Species, user: users(:rolf)
    )
    assert_equal(names(:chlorophyllum_rachodes),
                 deprecated_name.best_preferred_synonym)

    # > 1 preferred synonyms, > 1 with observations,
    # Neither has more Observations
    # Create an Observation for the other approved synonym, so that they'll
    # be tied in # of Observations
    revised_best_synonym = names(:chlorophyllum_rhacodes)
    Observation.create(
      name: revised_best_synonym,
      user: users(:rolf), when: Time.current, location: locations(:albion)
    )
    # other_approved_synonyms.name.observations is cached by Rails, so
    # it didn't change when we created the Observation above.
    # So reload it
    deprecated_name.other_approved_synonyms.
      find { |n| n == revised_best_synonym }.observations.reload
    assert_equal(revised_best_synonym,
                 deprecated_name.best_preferred_synonym)

    # > 1 preferred synonyms, > 1 with observations,
    # 1 has more obs than all the others
    # Make C. rachodes have 2 observations
    revised_best_synonym = names(:chlorophyllum_rachodes)
    Observation.create(
      name: revised_best_synonym,
      user: users(:rolf), when: Time.current, location: locations(:albion)
    )
    # other_approved_synonyms.name.observations is cached by Rails, so
    # it didn't change when we created the Observation above.
    # So reload it
    deprecated_name.other_approved_synonyms.
      find { |n| n == revised_best_synonym }.observations.reload
    assert_equal(revised_best_synonym,
                 deprecated_name.best_preferred_synonym)
  end

  def test_homonyms
    name = names(:hygrocybe_russocoriacea_good_author)
    expect = Name.where(text_name: name.text_name).pluck(:id)
    assert_equal(expect, name.other_author_ids, "Homonym ids incorrect")

    # This know too much about other_author_ids internals,
    # But how else can I do it? -- JDC 2020-12-16
    name.other_authors # sets @other_authors (in the context of name)
    assert_equal(expect, name.other_author_ids, "Homonym ids incorrect")

    name = names(:hygrocybe_russocoriacea_bad_author)
    expect = Name.where(text_name: name.text_name).to_a
    assert_equal(expect, name.other_authors, "Homonyms incorrect")

    name.other_author_ids # sets @other_author_ids (in the context of name)
    assert_equal(expect, name.other_authors, "Homonyms incorrect")
  end

  def test_clear_synonym
    name = names(:peltigera)
    misspelt = names(:petigera)
    assert(name.synonym)
    assert(misspelt.synonym)
    assert_equal(
      2, name.synonyms.count, "Test needs fixture with one other synonym"
    )

    name.clear_synonym

    assert_nil(name.synonym, "Failed to unsynonymize name")
    assert_nil(misspelt.reload.synonym,
               "Failed to unsynonymize misspelling of unsynonymized name")
    assert_nil(
      misspelt.correct_spelling,
      "Failed to clear misspelling when correct spelling un-synonymized"
    )
  end

  def test_more_popular
    approved_name = names(:lactarius_alpinus)
    deprecated_name = names(:lactarius_alpigenes)
    assert_equal(approved_name, approved_name.more_popular(deprecated_name),
                 "Approved name should be more popular than deprecated one")
    assert_equal(approved_name, deprecated_name.more_popular(approved_name),
                 "Approved name should be more popular than deprecated one")

    # Prove that more observed, approved Name is more popular than
    # less observed, but more recently proposed, approved Name
    more_observed_name = names(:fungi)
    less_observed_name = names(:coprinus_comatus)
    assert_operator(more_observed_name.observation_count, :>,
                    less_observed_name.observation_count,
                    "Test needs different fixtures")
    less_observed_naming = Naming.where(name: less_observed_name).first
    less_observed_naming.update(created_at: Time.zone.now + 1.hour)
    assert_equal(
      more_observed_name,
      more_observed_name.more_popular(less_observed_name),
      "More observed name should be more popular than " \
      "less observed, more-recently proposed name"
    )
    assert_equal(
      more_observed_name,
      less_observed_name.more_popular(more_observed_name),
      "More observed name should be more popular than " \
      "less observed, more-recently proposed name"
    )

    # Prove that more recently proposed, approved Name is more popular than
    # less recently proposed, approved Name with equal number of observations
    later_proposed_name = names(:tremella)
    earlier_proposed_name = names(:tremella_mesenterica)
    assert_equal(earlier_proposed_name.observation_count,
                 later_proposed_name.observation_count,
                 "Test needs different fixtures")
    later_proposed_naming = Naming.where(name: later_proposed_name).first
    later_proposed_naming.update(created_at: Time.zone.now + 1.hour)

    assert_equal(
      later_proposed_name,
      later_proposed_name.more_popular(earlier_proposed_name),
      "More recently proposed name should be more popular than " \
      "less recently proposed, approved Name with same number of observations"
    )
    assert_equal(
      later_proposed_name,
      earlier_proposed_name.more_popular(later_proposed_name),
      "More recently proposed name should be more popular than " \
      "less recently proposed, approved Name with same number of observations"
    )
  end

  # --------------------------------------
  #  formatting
  # --------------------------------------

  def test_display_name_brief_authors
    # Name 0 authors
    assert_equal(names(:russula_brevipes_no_author).display_name,
                 names(:russula_brevipes_no_author).display_name_brief_authors)

    # Name 1 author
    assert_equal(
      names(:russula_brevipes_author_notes).display_name,
      names(:russula_brevipes_author_notes).display_name_brief_authors
    )

    # Name 2 authors
    assert_equal(
      names(:hygrocybe_russocoriacea_good_author).display_name,
      names(:hygrocybe_russocoriacea_good_author).display_name_brief_authors
    )

    # Name > 2 authors
    assert_equal("**__Coprinellus micaceus__** (Bull.) Vilgalys et al.",
                 names(:coprinellus_micaceus).display_name_brief_authors)

    # Name > 2 authors in parentheses
    authors = "(Author1, Author2 & Author3) Author4, Author5 & Author6"
    name = Name.new(
      text_name: "Xxx #{authors}",
      display_name: "**__Xxx__** #{authors}",
      author: authors.to_s,
      rank: :Genus,
      deprecated: false, correct_spelling: nil,
      user: users(:rolf)
    )
    assert_equal("**__Xxx__** (Author1 et al.) Author4 et al.",
                 name.display_name_brief_authors)

    # Autonym <= 2 authors
    autonym = Name.new(
      text_name: "Russula sect. Russula",
      display_name: "**__Russula__** Pers. sect. **__Russula__**",
      author: "Pers.",
      rank: :Section,
      deprecated: false, correct_spelling: nil,
      user: users(:rolf)
    )
    assert_equal(autonym.display_name,
                 autonym.display_name_brief_authors)

    # Autonym > 2 authors
    authors = "Redhead, Vizzini, Drehmel & Contu"
    autonym = Name.new(
      text_name: "Saproamanita sect. Saproamanita",
      display_name: "**__Saproamanita__** #{authors} sect. Saproamanita",
      author: authors,
      rank: :Section,
      deprecated: false, correct_spelling: nil,
      user: users(:rolf)
    )
    assert_equal("**__Saproamanita__** Redhead et al. sect. Saproamanita",
                 autonym.display_name_brief_authors)

    # group <= 2 authors
    assert_equal(names(:authored_group).display_name,
                 names(:authored_group).display_name_brief_authors)

    # group > 2 authors
    authors = "Author1, Author2 & Author3"
    group_name = Name.new(
      text_name: "Xxx yyy clade #{authors}",
      display_name: "**__Xxx yyy__** clade #{authors}",
      author: authors,
      rank: :Group,
      deprecated: false, correct_spelling: nil,
      user: users(:rolf)
    )
    assert_equal("**__Xxx yyy__** clade Author1 et al.",
                 group_name.display_name_brief_authors)
  end

  def test_display_name_without_authors
    # Name with 0 authors
    assert_equal(
      names(:russula_brevipes_no_author).display_name,
      names(:russula_brevipes_no_author).display_name_without_authors
    )

    # Name with author
    assert_equal(
      "**__Russula brevipes__**",
      names(:russula_brevipes_author_notes).display_name_without_authors
    )

    # Autonym with author
    autonym = Name.create!(
      text_name: "Russula sect. Russula",
      display_name: "**__Russula__** Pers. sect. **__Russula__**",
      author: "Pers.",
      rank: :Section,
      deprecated: false, correct_spelling: nil,
      user: users(:rolf)
    )
    assert_equal("**__Russula__** sect. **__Russula__**",
                 autonym.display_name_without_authors)

    # group without author
    assert_equal(names(:unauthored_group).display_name,
                 names(:unauthored_group).display_name_without_authors)

    # group with author
    assert_equal("**__Groupauthored__** group",
                 names(:authored_group).display_name_without_authors)
  end

  def test_format_autonym
    assert_equal("**__Acarospora__**",
                 Name.format_autonym("Acarospora", "", :Genus, false))
    assert_equal("**__Acarospora__** L.",
                 Name.format_autonym("Acarospora", "L.", :Genus, false))
    assert_equal(
      "**__Acarospora nodulosa__** L.",
      Name.format_autonym("Acarospora nodulosa", "L.", :Species, false)
    )
    assert_equal(
      "__Acarospora nodulosa__ var. __reagens__ L.",
      Name.format_autonym(
        "Acarospora nodulosa var. reagens", "L.", :Variety, true
      )
    )
    assert_equal(
      "__Acarospora nodulosa__ L. var. __nodulosa__",
      Name.format_autonym(
        "Acarospora nodulosa var. nodulosa", "L.", :Variety, true
      )
    )
    assert_equal(
      "__Acarospora nodulosa__ L. ssp. __nodulosa__",
      Name.format_autonym(
        "Acarospora nodulosa ssp. nodulosa", "L.", :Subspecies, true
      )
    )
    assert_equal(
      "__Acarospora nodulosa__ L. f. __nodulosa__",
      Name.format_autonym(
        "Acarospora nodulosa f. nodulosa", "L.", :Form, true
      )
    )
    assert_equal(
      "__Acarospora nodulosa__ ssp. __reagens__ L. var. __reagens__",
      Name.format_autonym(
        "Acarospora nodulosa ssp. reagens var. reagens", "L.", :Variety, true
      )
    )
    assert_equal(
      "__Acarospora nodulosa__ L. ssp. __nodulosa__ var. __nodulosa__",
      Name.format_autonym(
        "Acarospora nodulosa ssp. nodulosa var. nodulosa", "L.", :Variety, true
      )
    )
    assert_equal(
      "__Acarospora nodulosa__ L. ssp. __nodulosa__ var. __nodulosa__ " \
      "f. __nodulosa__",
      Name.format_autonym(
        "Acarospora nodulosa ssp. nodulosa var. nodulosa f. nodulosa", "L.",
        :Form, true
      )
    )
  end

  def test_make_sure_names_are_bolded_correctly
    name = names(:suilus)
    assert_equal("**__#{name.text_name}__** #{name.author}", name.display_name)
    Name.make_sure_names_are_bolded_correctly
    name.reload
    assert_equal("__#{name.text_name}__ #{name.author}", name.display_name)
  end

  # --------------------------------------

  # Just make sure mysql is collating accents and case correctly.
  def test_mysql_sort_order
    return unless sql_collates_accents?

    names = [
      create_test_name("Agaricus Aehou"),
      create_test_name("Agaricus Aeiou"),
      create_test_name("Agaricus Aeiøu"),
      create_test_name("Agaricus Aëiou"),
      create_test_name("Agaricus Aéiou"),
      create_test_name("Agaricus Aejou")
    ]
    names[4].update(author: "aÉIOU")

    x = Name.where(id: names.map(&:id)).order(:author).pluck(:author)
    assert_equal(%w[Aehou Aeiou Aëiou aÉIOU Aeiøu Aejou], x)
  end

  # Prove that Name spaceship operator (<=>) uses sort_name to sort Names
  def test_name_spaceship_operator
    names = [
      create_test_name("Agaricomycota"),
      create_test_name("Agaricomycotina"),
      create_test_name("Agaricomycetes"),
      create_test_name("Agaricomycetidae"),
      create_test_name("Agaricales"),
      create_test_name("Agaricineae"),
      create_test_name("Agaricaceae"),
      create_test_name("Agaricus group"),
      create_test_name("Agaricus Aaron"),
      create_test_name("Agaricus L."),
      create_test_name("Agaricus Øosting"),
      create_test_name("Agaricus Zzyzx"),
      create_test_name("Agaricus Śliwa"),
      create_test_name("Agaricus Đorn"),
      create_test_name("Agaricus subgenus Dick"),
      create_test_name("Agaricus section Charlie"),
      create_test_name("Agaricus subsection Bob"),
      create_test_name("Agaricus stirps Arthur"),
      create_test_name("Agaricus aardvark"),
      create_test_name("Agaricus aardvark group"),
      create_test_name('Agaricus "tree-beard"'),
      create_test_name("Agaricus ugliano Zoom"),
      create_test_name("Agaricus ugliano ssp. ugliano Zoom"),
      create_test_name("Agaricus ugliano ssp. erik Zoom"),
      create_test_name("Agaricus ugliano var. danny Zoom"),
      create_test_name('Agaricus "sp-LD50"')
    ]
    x = Name.where(id: names.first.id..names.last.id).pluck(:sort_name)
    assert_equal(names.map(&:sort_name).sort, x.sort)
  end

  # Prove that alphabetized sort_names give us names in the expected order
  # Differs from test_name_spaceship_operator in omitting "Agaricus Śliwa",
  # whose sort_name is after all the levels between genus and species,
  # apparently because "Ś" sorts after "{".
  def test_name_sort_order
    names = [
      create_test_name("Agaricomycota"),
      create_test_name("Agaricomycotina"),
      create_test_name("Agaricomycetes"),
      create_test_name("Agaricomycetidae"),
      create_test_name("Agaricales"),
      create_test_name("Agaricineae"),
      create_test_name("Agaricaceae"),
      create_test_name("Agaricus group"),
      create_test_name("Agaricus Aaron"),
      create_test_name("Agaricus L."),
      create_test_name("Agaricus Øosting"),
      create_test_name("Agaricus Zzyzx"),
      create_test_name("Agaricus Đorn"),
      create_test_name("Agaricus subgenus Dick"),
      create_test_name("Agaricus section Charlie"),
      create_test_name("Agaricus subsection Bob"),
      create_test_name("Agaricus stirps Arthur"),
      create_test_name("Agaricus aardvark"),
      create_test_name("Agaricus aardvark group"),
      create_test_name('Agaricus "tree-beard"'),
      create_test_name("Agaricus ugliano Zoom"),
      create_test_name("Agaricus ugliano ssp. ugliano Zoom"),
      create_test_name("Agaricus ugliano ssp. erik Zoom"),
      create_test_name("Agaricus ugliano var. danny Zoom"),
      create_test_name('Agaricus "sp-LD50"')
    ]
    expected_sort_names = names.map(&:sort_name)
    sorted_sort_names = names.sort.map(&:sort_name)

    assert_equal(expected_sort_names, sorted_sort_names)
  end

  def test_guess_rank
    assert_equal(:Group, Name.guess_rank("Pleurotus djamor group"))
    assert_equal(:Group, Name.guess_rank("Pleurotus djamor var. djamor group"))
    assert_equal(:Form, Name.guess_rank("Pleurotus djamor var. djamor f. alba"))
    assert_equal(:Variety, Name.guess_rank("Pleurotus djamor var. djamor"))
    assert_equal(:Subspecies, Name.guess_rank("Pleurotus djamor subsp. djamor"))
    assert_equal(:Species, Name.guess_rank("Pleurotus djamor"))
    assert_equal(:Species, Name.guess_rank("Pleurotus djamor-foo"))
    assert_equal(:Species, Name.guess_rank("Phellinus robineae"))
    assert_equal(:Genus, Name.guess_rank("Pleurotus"))
    assert_equal(:Stirps, Name.guess_rank("Amanita stirps Grossa"))
    assert_equal(:Stirps,
                 Name.guess_rank("Amanita sect. Amanita stirps Grossa"))
    assert_equal(:Subsection, Name.guess_rank("Amanita subsect. Amanita"))
    assert_equal(:Section, Name.guess_rank("Amanita sect. Amanita"))
    assert_equal(:Section, Name.guess_rank("Hygrocybe sect. Coccineae"))
    assert_equal(:Subgenus, Name.guess_rank("Amanita subgenus Amanita"))
    assert_equal(:Family, Name.guess_rank("Amanitaceae"))
    assert_equal(:Family, Name.guess_rank("Peltigerineae"))
    assert_equal(:Order, Name.guess_rank("Peltigerales"))
    assert_equal(:Order, Name.guess_rank("Lecanoromycetidae"))
    assert_equal(:Class, Name.guess_rank("Lecanoromycetes"))
    assert_equal(:Class, Name.guess_rank("Agaricomycotina"))
    assert_equal(:Phylum, Name.guess_rank("Agaricomycota"))
    assert_equal(:Genus, Name.guess_rank("Animalia"))
    assert_equal(:Genus, Name.guess_rank("Plantae"))
    assert_equal(:Phylum, Name.guess_rank("Fossil-Fungi"))
    assert_equal(:Phylum, Name.guess_rank("Fossil-Ascomycota"))
    assert_equal(:Class, Name.guess_rank("Fossil-Ascomycetes"))
    assert_equal(:Order, Name.guess_rank("Fossil-Agaricales"))
    assert_equal(:Phylum, Name.guess_rank("Fossil-Anythingelse"))
  end

  def test_parent_if_parent_deprecated
    User.current = rolf
    lepiota = names(:lepiota)
    lepiota.change_deprecated(true)
    lepiota.save
    assert_nil(Name.parent_if_parent_deprecated("Agaricus campestris"))
    assert_nil(Name.parent_if_parent_deprecated("Agaricus campestris ssp. foo"))
    assert_nil(
      Name.parent_if_parent_deprecated("Agaricus campestris ssp. foo var. bar")
    )
    assert(Name.parent_if_parent_deprecated("Lactarius alpigenes"))
    assert(Name.parent_if_parent_deprecated("Lactarius alpigenes ssp. foo"))
    assert(
      Name.parent_if_parent_deprecated("Lactarius alpigenes ssp. foo var. bar")
    )
    assert_nil(Name.parent_if_parent_deprecated("Peltigera"))
    assert_nil(Name.parent_if_parent_deprecated("Peltigera neckeri"))
    assert_nil(Name.parent_if_parent_deprecated("Peltigera neckeri f. alba"))
    assert(Name.parent_if_parent_deprecated("Lepiota"))
    assert(Name.parent_if_parent_deprecated("Lepiota barsii"))
    assert(Name.parent_if_parent_deprecated("Lepiota barsii f. alba"))
  end

  def test_names_from_synonymous_genera
    User.current = rolf
    a = create_test_name("Agaricus")
    a1 = create_test_name("Agaricus testus")
    a3 = create_test_name("Agaricus testii")
    b = create_test_name("Pseudoagaricum")
    b1 = create_test_name("Pseudoagaricum testum")
    c = create_test_name("Hyperagarica")
    c1 = create_test_name("Hyperagarica testa")
    d = names(:lepiota)
    b.change_deprecated(true)
    b.save
    c.change_deprecated(true)
    c.save
    d.change_deprecated(true)
    d.save
    a3.change_deprecated(true)
    a3.save
    b1.change_deprecated(true)
    b1.save
    c1.change_deprecated(true)
    c1.save
    d.merge_synonyms(a)
    d.merge_synonyms(b)
    d.merge_synonyms(c)

    assert_obj_list_equal([a1],
                          Name.names_from_synonymous_genera("Lepiota testa"))
    assert_obj_list_equal([a1],
                          Name.names_from_synonymous_genera("Lepiota testus"))
    assert_obj_list_equal([a1],
                          Name.names_from_synonymous_genera("Lepiota testum"))
    assert_obj_list_equal([a3],
                          Name.names_from_synonymous_genera("Lepiota testii"))

    a1.change_deprecated(true)
    a1.save
    assert_obj_list_equal([a1, b1, c1],
                          Name.names_from_synonymous_genera("Lepiota testa"))
  end

  def test_suggest_alternate_spelling
    genus1 = create_test_name("Lecanora")
    genus2 = create_test_name("Lecania")
    species1 = create_test_name("Lecanora galactina")
    species2 = create_test_name("Lecanora galactinula")
    species3 = create_test_name("Lecanora grantii")
    species4 = create_test_name("Lecanora grandis")
    species5 = create_test_name("Lecania grandis")

    assert_name_list_equal([genus1],
                           Name.guess_with_errors("Lecanora", 1))
    assert_name_list_equal([genus1, genus2],
                           Name.guess_with_errors("Lecanoa", 1))
    assert_name_list_equal([],
                           Name.guess_with_errors("Lecanroa", 1))
    assert_name_list_equal([genus1, genus2],
                           Name.guess_with_errors("Lecanroa", 2))
    assert_name_list_equal([genus1],
                           Name.guess_with_errors("Lecanosa", 1))
    assert_name_list_equal([genus1, genus2],
                           Name.guess_with_errors("Lecanosa", 2))
    assert_name_list_equal([genus1, genus2],
                           Name.guess_with_errors("Lecanroa", 3))
    assert_name_list_equal([genus1],
                           Name.guess_with_errors("Lacanora", 1))
    assert_name_list_equal([genus1],
                           Name.guess_with_errors("Lacanora", 2))
    assert_name_list_equal([genus1],
                           Name.guess_with_errors("Lacanora", 3))
    assert_name_list_equal([genus1],
                           Name.guess_word("", "Lacanora"))
    assert_name_list_equal([genus1, genus2],
                           Name.guess_word("", "Lecanroa"))

    assert_name_list_equal([species1, species2],
                           Name.guess_with_errors("Lecanora galactina", 1))
    assert_name_list_equal([species3],
                           Name.guess_with_errors("Lecanora granti", 1))
    assert_name_list_equal([species3, species4],
                           Name.guess_with_errors("Lecanora granti", 2))
    assert_name_list_equal([],
                           Name.guess_with_errors("Lecanora gran", 3))
    assert_name_list_equal([species3],
                           Name.guess_word("Lecanora", "granti"))

    assert_name_list_equal([names(:lecanorales), genus1],
                           Name.suggest_alternate_spellings("Lecanora"))
    assert_name_list_equal([names(:lecanorales), genus1],
                           Name.suggest_alternate_spellings("Lecanora\\"))
    assert_name_list_equal([genus1, genus2],
                           Name.suggest_alternate_spellings("Lecanoa"))
    assert_name_list_equal([species3],
                           Name.suggest_alternate_spellings("Lecanora granti"))
    assert_name_list_equal([species3, species4],
                           Name.suggest_alternate_spellings("Lecanora grandi"))
    assert_name_list_equal([species4, species5],
                           Name.suggest_alternate_spellings("Lecanoa grandis"))
  end

  # --------------------------------------

  def test_approved_synonym_of_proposed_name_has_dependents
    approved_synonym = names(:lactarius_alpinus)
    deprecated_name = names(:lactarius_alpigenes)
    assert(!approved_synonym.deprecated &&
           deprecated_name.synonym == approved_synonym.synonym &&
           deprecated_name.correctly_spelt?,
           "Test needs different fixture(s): " \
           "an Approved Name, with a Deprecated Synonym" \
           "the Deprecated Name being correctly spelt")
    Naming.create(user: mary,
                  name: deprecated_name,
                  observation: observations(:minimal_unknown_obs))

    assert(
      approved_synonym.dependents?,
      "`dependents?` should be true for an approved synonym " \
      "(#{approved_synonym.text_name}) of " \
      "a correctly spelt Proposed Name (#{deprecated_name.text_name})"
    )
  end

  def test_approved_synonym_of_mispelt_name_has_no_dependents
    approved_synonym = names(:peltigera)
    deprecated_name = names(:petigera)
    assert(!approved_synonym.deprecated &&
           deprecated_name.synonym == approved_synonym.synonym &&
           deprecated_name.is_misspelling?,
           "Test needs different fixture(s): " \
           "an Approved Name, with a Deprecated Synonym" \
           "the Deprecated Name being misspelt")
    Naming.create(user: mary,
                  name: deprecated_name,
                  observation: observations(:minimal_unknown_obs))

    assert_not(
      approved_synonym.dependents?,
      "`dependents?` should be false for an approved synonym " \
      "(#{approved_synonym.text_name}) of " \
      "a misspelt Proposed Name (#{deprecated_name.text_name})"
    )
  end

  def test_correctly_spelled_ancestor_of_proposed_name_has_dependents
    ancestor = names(:basidiomycetes)
    assert(
      !ancestor.is_misspelling? &&
      Name.joins(:namings).where(
        "classification LIKE ?",
        "%#{ancestor.rank}: _#{ancestor.text_name}_%"
      ).any?,
      "Test needs different fixture: A correctly spelled Name " \
      "at a rank that has Namings classified with that rank."
    )
    assert(
      ancestor.dependents?,
      "`dependents?` should be true for a Name above genus " \
      "(#{ancestor.text_name}) that is a correctly spelled ancestor "\
      "of a Proposed Name"
    )

    ancestor = names(:boletus)
    assert(
      ancestor.dependents?,
      "`dependents?` should be true for a Genus (#{ancestor.text_name}) " \
      "that is an ancestor of a Proposed Name."
    )

    ancestor = names(:amanita_boudieri)
    Naming.create(user: mary,
                  name: names(:amanita_boudieri_var_beillei),
                  observation: observations(:minimal_unknown_obs))
    assert(
      ancestor.dependents?,
      "`dependents?` should be true for Species (#{ancestor.text_name}) " \
      "that is an ancestor of a Proposed Name."
    )
  end

  def test_misspelt_ancestor_of_misspelt_proposed_name_has_no_dependents
    misspelt_genus = names(:suilus)
    species_of_missplet_genus = Name.create(
      text_name: "#{misspelt_genus.text_name} lakei",
      display_name: "__#{misspelt_genus.text_name} lakei__",
      rank: :Species,
      user: dick,
      correct_spelling: names(:boletus_edulis) # anything will do
    )
    Naming.create(user: mary,
                  name: species_of_missplet_genus,
                  observation: observations(:minimal_unknown_obs))

    assert_not(
      misspelt_genus.dependents?,
      "`dependents?` should be false for " \
      "misspelt genus of misspelt Proposed Name " \
    )
  end

  def test_ancestor_of_correctly_spelled_unproposed_name_has_dependents
    ancestor = Name.create(
      text_name: "Phyllotopsidaceae",
      search_name: "Phyllotopsidaceae",
      sort_name: "Phyllotopsidaceae",
      display_name: "**__Phyllotopsidaceae__**",
      rank: Name.ranks[:Family],
      user: dick
    )
    descendant = Name.create(
      text_name: "Macrotyphula",
      search_name: "Macrotyphula",
      sort_name: "Macrotyphula",
      display_name: "**__Macrotyphula__**",
      rank: Name.ranks[:Genus],
      classification: "Family: _#{ancestor.text_name}_",
      user: dick
    )
    assert(ancestor.dependents?,
           "`dependents?` should be true because " \
           "#{ancestor.text_name} is an ancestor of #{descendant.text_name}")

    ancestor = names(:tubaria)
    descendant = names(:tubaria_furfuracea)
    assert(
      Naming.where(name: descendant).none? && !descendant.is_misspelling?,
      "Test needs different fixture: correctly spelled, without Namings"
    )
    assert(ancestor.dependents?,
           "`dependents?` should be true because " \
           "#{ancestor.text_name} is an ancestor of #{descendant.text_name}")
  end

  # --------------------------------------

  def test_imageless
    assert_true(names(:imageless).imageless?)
    assert_false(names(:fungi).imageless?)
  end

  def test_names_matching_desired_new_name
    # Prove unauthored ParseName matches are all extant matches to text_name
    # Such as multiple authored Names
    parsed = Name.parse_name("Amanita baccata")
    expect = [names(:amanita_baccata_arora), names(:amanita_baccata_borealis)]
    assert_equal(expect,
                 Name.names_matching_desired_new_name(parsed).order(:author))
    # or unauthored and authored Names
    parsed = Name.parse_name(names(:unauthored_with_naming).text_name)
    expect = [names(:unauthored_with_naming), names(:authored_with_naming)]
    assert_equal(expect,
                 Name.names_matching_desired_new_name(parsed).order(:author))

    # Prove authored Group ParsedName is not matched by extant unauthored Name
    parsed = Name.parse_name("#{names(:unauthored_group).text_name} Author")
    assert_not(Name.names_matching_desired_new_name(parsed).
                include?(names(:unauthored_with_naming)))
    # And vice versa
    # Prove unauthored Group ParsedName is not matched by extant authored Name
    extant = names(:authored_group)
    desired = extant.text_name
    parsed = Name.parse_name(desired)
    assert_not(Name.names_matching_desired_new_name(parsed).include?(extant),
               "'#{desired}' unexpectedly matches '#{extant.search_name}'")

    # Prove authored non-Group ParsedName matched by union of exact matches and
    # unauthored matches
    parsed = Name.parse_name(names(:authored_with_naming).search_name)
    expect = [names(:unauthored_with_naming), names(:authored_with_naming)]
    assert_equal(expect,
                 Name.names_matching_desired_new_name(parsed).order(:author))
  end

  def test_refresh_classification_caches
    name = names(:coprinus_comatus)
    bad  = name.classification = "Phylum: _Ascomycota_"
    good = name.description.classification
    name.save
    assert_not_equal(good, bad)

    Name.refresh_classification_caches
    assert_equal(good, name.reload.classification)
    assert_equal(good, name.description.reload.classification)
  end

  def test_changing_classification_propagates_to_subtaxa
    name  = names(:coprinus)
    child = names(:coprinus_comatus)
    new_classification = names(:peltigera).classification
    assert_not_equal(new_classification, name.classification)
    assert_not_equal(new_classification, child.classification)
    name.description.classification = new_classification
    name.description.save
    assert_equal(new_classification, name.reload.classification)
    assert_equal(new_classification, child.reload.classification)
  end

  def test_mark_misspelled
    # Make sure target name has synonyms.
    syn = Synonym.create
    Name.connection.execute(%(
      UPDATE names SET synonym_id = #{syn.id}
      WHERE text_name LIKE "Agaricus camp%"
    ))

    good = names(:agaricus_campestris)
    bad  = names(:coprinus_comatus)
    old_obs = Observation.where(name: bad)
    old_synonym_count = good.synonyms.count

    bad.mark_misspelled(good, :save)
    good.reload
    bad.reload

    assert_true(bad.deprecated)
    assert_false(good.deprecated)
    assert_equal("__#{bad.text_name}__ #{bad.author}", bad.display_name)
    assert_equal("**__#{good.text_name}__** #{good.author}", good.display_name)
    assert_names_equal(good, bad.correct_spelling)
    assert_nil(good.correct_spelling)
    assert_objs_equal(syn, bad.synonym)
    assert_equal(old_synonym_count + 1, bad.synonyms.count)
    old_obs.each do |obs|
      assert_names_equal(good, obs.name)
    end
  end

  def test_clear_misspelled
    good = names(:peltigera)
    bad  = names(:petigera)
    bad.clear_misspelled(:save)
    good.reload
    bad.reload

    assert_true(bad.deprecated)
    assert_false(good.deprecated)
    assert_equal("__#{bad.text_name}__", bad.display_name)
    assert_equal("**__#{good.text_name}__** #{good.author}", good.display_name)
    assert_nil(bad.correct_spelling)
    assert_nil(good.correct_spelling)
    assert_not_nil(good.synonym_id)
    assert_objs_equal(good.synonym, bad.synonym)
  end

  def test_registability
    name = names(:boletus_edulis_group)
    assert(name.unregistrable?, "Groups should be unregistrable")

    name = Name.new(text_name: 'Cortinarus "quoted"', rank: :Species)
    assert(name.unregistrable?,
           "Names below genus with quotes should be unregistrable")

    name = Name.new(text_name: "Agaricus pinyonensis",
                    author: "Isaacs nom. prov.")
    assert(name.unregistrable?, "Provisional names should be unregistrable")

    name = Name.new(text_name: "Fulvifomes porrectus",
                    author: "comb. prov.")
    assert(name.unregistrable?, "Provisional names should be unregistrable")

    name = Name.new(text_name: "Cortinarius calaisopus", author: "ined.")
    assert(name.unregistrable?, "Unpublished names should be unregistrable")

    name = Name.new(text_name: "Agricales", author: "sensu lato")
    assert(name.unregistrable?, "Names s.l. should be unregistrable")

    name = Name.new(text_name: "Eukaryota", rank: :Domain)
    assert(name.unregistrable?, "Domains should be unregistrable")

    name = Name.new(text_name: "Ericales", classification: "Kingdom: _Plantae_")
    assert(name.unregistrable?,
           "Taxa outside of Fungi and slime molds should be unregistrable")

    name = names(:coprinus)
    assert(name.registrable?, "Non-group fungal names should be registrable")

    # Use Protozoa as a rough proxy for slime molds, which are included
    # fungal nomenclature registries, even though they are not fungi.
    name = Name.new(text_name: "Myxomycetes", rank: :Class,
                    classification: "Kingdom: Protozoa")
    assert(name.registrable?, "Protozoa should be registrable")

    name = Name.new(text_name: "New species", rank: :Species)
    assert(name.registrable?,
           "Non-group, non-domain kingdom-less names should be registrable")
  end

  def test_searchability_in_registry
    name = Name.new(text_name: "Eukaryota", rank: :Domain)
    assert(name.unsearchable_in_registry?, "Domains should be unsearchable")

    name = Name.new(text_name: "Ericales", classification: "Kingdom: _Plantae_")
    assert(name.unsearchable_in_registry?,
           "Taxa outside of Fungi and slime molds should be unsearchable")

    name = Name.new(text_name: 'Amanita "sp-01"', author: "crypt. temp.")
    assert(name.unsearchable_in_registry?,
           "Cryptonyms should be unsearchable")

    name = names(:boletus_edulis_group)
    assert(name.searchable_in_registry?,
           "Fungal `groups` can be searchable in registy")

    name = Name.new(text_name: 'Cortinarus "quoted"', rank: :Species)
    assert(name.searchable_in_registry?,
           "Names with quote marks can be searchable")

    name = Name.new(text_name: "Agaricus pinyonensis",
                    author: "Isaacs nom. prov.")
    assert(name.searchable_in_registry?,
           "Provisional names can be searchable in registry")

    name = Name.new(text_name: "Myxomycetes", rank: :Class,
                    classification: "Kingdom: Protozoa")
    assert(name.searchable_in_registry?,
           "Protozoa should be searchable in registry")
  end

  # The ":Fr" in this used to raise an ActiveRecord error because it was
  # interpreting it as a named variable.
  def test_guess_name_with_colon_in_pattern
    # Apparently assert_nothing_raised hides debug information but gives
    # nothing useful in return.
    Name.guess_with_errors("Crepidotus applanatus(Pers.:Fr.)Kummer", 1)
  end

  def test_merge_interests
    old_name = names(:agaricus_campestros)
    interests = old_name.interests
    assert(interests.any?, "Test needs a fixture with an interest")
    target = names(:agaricus_campestras)
    assert(target.interests.none?, "Test needs a fixture without interests")

    target.merge(old_name)
    assert_equal(
      interests, target.interests,
      "Old name (#{old_name.text_name}) interests " \
      "were not moved to target (#{target.text_name})"
    )
  end

  def test_fix_self_referential_misspellings
    msgs = Name.fix_self_referential_misspellings
    assert_empty(msgs)

    name = names(:coprinus)
    name.update(correct_spelling_id: name.id)
    msgs = Name.fix_self_referential_misspellings
    assert_equal(1, msgs.length)
    name.reload
    assert_nil(name.correct_spelling_id)
  end

  def test_genus_of_synonym
    names(:coprinus_comatus).merge_synonyms(names(:stereum_hirsutum))
    names(:coprinus_comatus).update(deprecated: true)
    assert_names_equal(names(:stereum), names(:coprinus_comatus).accepted_genus)
    assert_names_equal(names(:stereum), names(:stereum_hirsutum).accepted_genus)
  end

  def test_propagate_generic_classifications
    # This should result in the classification of Coprinus being copied to
    # Chlorophyllum rachodes.
    c_rachodes = names(:chlorophyllum_rachodes)
    c_comatus = names(:coprinus_comatus)
    c_rachodes.merge_synonyms(c_comatus)
    c_rachodes.update(deprecated: true)
    c_comatus.update(deprecated: false)
    wrong_class = c_rachodes.classification.sub(/Agaricaceae/, "Boletaceae")
    c_rachodes.update(classification: wrong_class)
    c_rachodes.reload
    c_comatus.reload
    assert_not_empty(c_rachodes.observations)
    assert_not_equal(c_rachodes.classification, names(:coprinus).classification)

    # This should result in the species in Agaricus having their
    # classifications stripped.  (Presently, I'm deeming this safer than
    # trusting old classifications which cannot even be seen on the website
    # anymore. It should be impossible to set a species's classification
    # to be different from the genus deliberately these days.)
    a_campestris = names(:agaricus_campestris)
    observations(:agaricus_campestrus_obs).destroy
    observations(:agaricus_campestras_obs).destroy
    observations(:agaricus_campestros_obs).destroy
    names(:agaricus).update(classification: nil)
    assert_not_empty(a_campestris.observations)

    # It should fill these in from Lepiota.
    l_rachodes = names(:lepiota_rachodes)
    l_rhacodes = names(:lepiota_rhacodes)
    l_rachodes.update(classification: nil)
    l_rhacodes.update(classification: "")
    observations(:minimal_unknown_obs).update(
      name: l_rhacodes,
      text_name: l_rhacodes.text_name
    )
    assert_empty(l_rachodes.observations)
    assert_not_empty(l_rhacodes.observations)

    # Make sure observations.text_name mirror is fully populated!
    Observation.refresh_content_filter_caches

    msgs = Name.propagate_generic_classifications

    # Should be, in any order:
    #   Fixing classification for C... rachodes: Boletaceae => Agaricaceae
    #   Stripping classification from Agaricus campestris
    #   Filling in classification for Lepiota rhacodes
    #   Setting classifications for blah,blah,blah.
    #   Setting classifications for blah,blah,blah,blah.
    assert(
      msgs.include?("Fixing classification of Chlorophyllum rachodes: " \
                    "Boletaceae => Agaricaceae") &&
        msgs.include?("Filling in classification for Lepiota rhacodes") &&
        msgs.include?("Stripping classification from Agaricus campestris") &&
        !msgs.include?("Filling in classification for Lepiota rachodes") &&
        !msgs.include?("Stripping classification from Agaricus campestras"),
      "Messages wrong.  Got this:\n#{msgs.inspect}\n"
    )

    # Make sure reported changes were actually made...
    assert_equal(c_comatus.classification, c_rachodes.reload.classification)
    assert_nil(a_campestris.reload.classification)
    assert_nil(names(:agaricus_campestrus).classification)
    assert_equal(names(:lepiota).classification,
                 l_rachodes.reload.classification)
    assert_equal(names(:lepiota).classification,
                 l_rhacodes.reload.classification)
  end
end
