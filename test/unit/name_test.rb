require File.dirname(__FILE__) + '/../boot'

class NameTest < Test::Unit::TestCase

  def create_test_name(string, force_rank=nil)
    User.current = @rolf
    (text_name, display_name, observation_name, search_name, parent_name, rank, author) = Name.parse_name(string)
    name = Name.create_name(force_rank || rank, text_name, author, display_name, observation_name, search_name)
    assert(name.save, "Error saving name \"#{string}\": [#{name.dump_errors}]")
    return name
  end

  def do_name_parse_test(*args)
    parse = Name.parse_name(args.shift)
    assert_equal(args, parse)
  end

  def do_parse_classification_test(text, expected)
    begin
      parse = Name.parse_classification(text)
      assert_equal(expected, parse)
    rescue RuntimeError => err
      raise err if expected
    end
  end

  def do_validate_classification_test(rank, text, expected)
    begin
      result = Name.validate_classification(rank, text)
      assert_equal(expected, result)
    rescue RuntimeError => err
      raise err if expected
    end
  end

################################################################################

  # ----------------------------
  #  Test name parsing.
  # ----------------------------

  # Create new subspecies Coprinus comatus v. bogus and make sure it doesn't
  # create a duplicate species if one already exists.
  # Saw this bug 20080114 -JPH
  def test_names_from_string

    # Coprinus comatus already has an author.
    result = Name.names_from_string("Coprinus comatus v. bogus (With) Author")
    assert_equal 3, result.length
    assert_equal nil, result[0].id
    assert_equal 2,   result[1].id
    assert_equal nil, result[2].id
    assert_equal "Coprinus", result[0].text_name
    assert_equal "Coprinus comatus", result[1].text_name
    assert_equal "Coprinus comatus var. bogus", result[2].text_name
    assert_equal nil, result[0].author
    assert_equal "(O.F. Müll.) Pers.", result[1].author
    assert_equal "(With) Author", result[2].author

    # Conocybe filaris does not have an author.
    result = Name.names_from_string("Conocybe filaris var bogus (With) Author")
    assert_equal 3, result.length
    assert_equal nil, result[0].id
    assert_equal 4,   result[1].id
    assert_equal nil, result[2].id
    assert_equal "Conocybe", result[0].text_name
    assert_equal "Conocybe filaris", result[1].text_name
    assert_equal "Conocybe filaris var. bogus", result[2].text_name
    assert_equal nil, result[0].author
    assert_equal nil, result[1].author
    assert_equal "(With) Author", result[2].author

    # Agaricus does not have an author.
    result = Name.names_from_string("Agaricus L.")
    assert_equal 1, result.length
    assert_equal 18, result[0].id
    assert_equal "Agaricus", result[0].text_name
    assert_equal "L.", result[0].author

    # Agaricus does not have an author.
    result = Name.names_from_string("Agaricus abra f. cadabra (With) Another Author")
    assert_equal 3, result.length
    assert_equal 18, result[0].id
    assert_equal nil, result[1].id
    assert_equal nil, result[2].id
    assert_equal "Agaricus", result[0].text_name
    assert_equal "Agaricus abra", result[1].text_name
    assert_equal "Agaricus abra f. cadabra", result[2].text_name
    assert_equal nil, result[0].author
    assert_equal nil, result[1].author
    assert_equal "(With) Another Author", result[2].author
  end

  def test_name_parse_1
    do_name_parse_test(
      'Lecania ryaniana van den Boom',
      'Lecania ryaniana',
      '**__Lecania ryaniana__** van den Boom',
      '**__Lecania ryaniana__** van den Boom',
      'Lecania ryaniana van den Boom',
      'Lecania',
      :Species,
      'van den Boom'
    )
  end

  def test_name_parse_2
    do_name_parse_test(
      'Lecidea sanguineoatra sens. Nyl',
      'Lecidea sanguineoatra',
      '**__Lecidea sanguineoatra__** sens. Nyl',
      '**__Lecidea sanguineoatra__** sens. Nyl',
      'Lecidea sanguineoatra sens. Nyl',
      'Lecidea',
      :Species,
      'sens. Nyl'
    )
  end

  def test_name_parse_3
    do_name_parse_test(
      'Acarospora squamulosa sensu Th. Fr.',
      'Acarospora squamulosa',
      '**__Acarospora squamulosa__** sensu Th. Fr.',
      '**__Acarospora squamulosa__** sensu Th. Fr.',
      'Acarospora squamulosa sensu Th. Fr.',
      'Acarospora',
      :Species,
      'sensu Th. Fr.'
    )
  end

  def test_name_parse_4
    do_name_parse_test(
      'Cladina portentosa subsp. pacifica f. decolorans auct.',
      'Cladina portentosa subsp. pacifica f. decolorans',
      '**__Cladina portentosa__** subsp. **__pacifica__** f. **__decolorans__** auct.',
      '**__Cladina portentosa__** subsp. **__pacifica__** f. **__decolorans__** auct.',
      'Cladina portentosa subsp. pacifica f. decolorans auct.',
      'Cladina portentosa subsp. pacifica',
      :Form ,
      'auct.'
    )
  end

  def test_name_parse_5
    do_name_parse_test(
      'Japewia tornoënsis Somloë',
      'Japewia tornoensis',
      '**__Japewia tornoënsis__** Somloë',
      '**__Japewia tornoënsis__** Somloë',
      'Japewia tornoensis Somloë',
      'Japewia',
      :Species,
      'Somloë'
    )
  end

  def test_name_parse_6
    do_name_parse_test(
      'Micarea globularis "(Ach. ex Nyl.) Hedl."',
      'Micarea globularis',
      '**__Micarea globularis__** "(Ach. ex Nyl.) Hedl."',
      '**__Micarea globularis__** "(Ach. ex Nyl.) Hedl."',
      'Micarea globularis "(Ach. ex Nyl.) Hedl."',
      'Micarea',
      :Species,
      '"(Ach. ex Nyl.) Hedl."'
    )
  end

  def test_name_parse_7
    do_name_parse_test(
      'Synechoblastus aggregatus ("Ach.") Th. Fr.',
      'Synechoblastus aggregatus',
      '**__Synechoblastus aggregatus__** ("Ach.") Th. Fr.',
      '**__Synechoblastus aggregatus__** ("Ach.") Th. Fr.',
      'Synechoblastus aggregatus ("Ach.") Th. Fr.',
      'Synechoblastus',
      :Species,
      '("Ach.") Th. Fr.'
    )
  end

  def test_name_parse_8
    do_name_parse_test(
      '"Toninia"',
      '"Toninia"',
      '**__"Toninia"__**',
      '**__"Toninia" sp.__**',
      '"Toninia" sp.',
      nil,
      :Genus,
      nil
    )
  end

  def test_name_parse_9
    do_name_parse_test(
      '"Toninia" sp.',
      '"Toninia"',
      '**__"Toninia"__**',
      '**__"Toninia" sp.__**',
      '"Toninia" sp.',
      nil,
      :Genus,
      nil
    )
  end

  def test_name_parse_10
    do_name_parse_test(
      '"Toninia" squalescens',
      '"Toninia" squalescens',
      '**__"Toninia" squalescens__**',
      '**__"Toninia" squalescens__**',
      '"Toninia" squalescens',
      '"Toninia"',
      :Species,
      nil
    )
  end

  def test_name_parse_11
    do_name_parse_test(
      'Anaptychia "leucomelaena" auct.',
      'Anaptychia "leucomelaena"',
      '**__Anaptychia "leucomelaena"__** auct.',
      '**__Anaptychia "leucomelaena"__** auct.',
      'Anaptychia "leucomelaena" auct.',
      'Anaptychia',
      :Species,
      'auct.'
    )
  end

  def test_name_parse_12
    do_name_parse_test(
      'Anema',
      'Anema',
      '**__Anema__**',
      '**__Anema sp.__**',
      'Anema sp.',
      nil,
      :Genus,
      nil
    )
  end

  def test_name_parse_13
    do_name_parse_test(
      'Anema sp',
      'Anema',
      '**__Anema__**',
      '**__Anema sp.__**',
      'Anema sp.',
      nil,
      :Genus,
      nil
    )
  end

  def test_name_parse_14
    do_name_parse_test(
      'Anema sp.',
      'Anema',
      '**__Anema__**',
      '**__Anema sp.__**',
      'Anema sp.',
      nil,
      :Genus,
      nil
    )
  end

  def test_name_parse_15
    do_name_parse_test(
      'Anema Nyl. ex Forss.',
      'Anema',
      '**__Anema__** Nyl. ex Forss.',
      '**__Anema sp.__** Nyl. ex Forss.',
      'Anema sp. Nyl. ex Forss.',
      nil,
      :Genus,
      'Nyl. ex Forss.'
    )
  end

  def test_name_parse_16
    do_name_parse_test(
      'Anema sp Nyl. ex Forss.',
      'Anema',
      '**__Anema__** Nyl. ex Forss.',
      '**__Anema sp.__** Nyl. ex Forss.',
      'Anema sp. Nyl. ex Forss.',
      nil,
      :Genus,
      'Nyl. ex Forss.'
    )
  end

  def test_name_parse_17
    do_name_parse_test(
      'Anema sp. Nyl. ex Forss.',
      'Anema',
      '**__Anema__** Nyl. ex Forss.',
      '**__Anema sp.__** Nyl. ex Forss.',
      'Anema sp. Nyl. ex Forss.',
      nil,
      :Genus,
      'Nyl. ex Forss.'
    )
  end

  def test_name_parse_18
    do_name_parse_test(
      'Japewia tornoënsis var. tornoënsis',
      'Japewia tornoensis var. tornoensis',
      '**__Japewia tornoënsis__** var. **__tornoënsis__**',
      '**__Japewia tornoënsis__** var. **__tornoënsis__**',
      'Japewia tornoensis var. tornoensis',
      'Japewia tornoënsis',
      :Variety,
      nil
    )
  end

  def test_name_parse_19
    do_name_parse_test(
      'Does this ssp. ever var. happen f. for Real?',
      'Does this subsp. ever var. happen f. for',
      '**__Does this__** subsp. **__ever__** var. **__happen__** f. **__for__** Real?',
      '**__Does this__** subsp. **__ever__** var. **__happen__** f. **__for__** Real?',
      'Does this subsp. ever var. happen f. for Real?',
      'Does this ssp. ever var. happen',
      :Form,
      'Real?'
    )
  end

  def test_name_parse_20
    do_name_parse_test(
      'Boletus  rex-veris Arora & Simonini',
      'Boletus rex-veris',
      '**__Boletus rex-veris__** Arora & Simonini',
      '**__Boletus rex-veris__** Arora & Simonini',
      'Boletus rex-veris Arora & Simonini',
      'Boletus',
      :Species,
      'Arora & Simonini'
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
      Family: Amanitaceae\r
      Genus: Amanita),
      [[:Kingdom, "Fungi"],
       [:Phylum, "Basidiomycota"],
       [:Class, "Basidiomycetes"],
       [:Order, "Agaricales"],
       [:Family, "Amanitaceae"],
       [:Genus, "Amanita"]
      ])
  end

  def test_parse_classification_3
    do_parse_classification_test(%(Kingdom: Fungi\r
      \r
      Genus: Amanita),
      [[:Kingdom, "Fungi"],
       [:Genus, "Amanita"]
      ])
  end

  def test_parse_classification_4
    do_parse_classification_test(%(Kingdom: _Fungi_\r
      Genus: _Amanita_),
      [[:Kingdom, "Fungi"],
       [:Genus, "Amanita"]
      ])
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
    do_validate_classification_test(:Species, "Kingdom: Fungi", "Kingdom: _Fungi_")
  end

  def test_validate_classification_2
    do_validate_classification_test(:Species, %(Kingdom: Fungi\r
      Phylum: Basidiomycota\r
      Class: Basidiomycetes\r
      Order: Agaricales\r
      Family: Amanitaceae\r
      Genus: Amanita),
      "Kingdom: _Fungi_\r\nPhylum: _Basidiomycota_\r\nClass: _Basidiomycetes_\r\n" +
      "Order: _Agaricales_\r\nFamily: _Amanitaceae_\r\nGenus: _Amanita_")
  end

  def test_validate_classification_3
    do_validate_classification_test(:Species, %(Kingdom: Fungi\r
      \r
      Genus: Amanita),
      "Kingdom: _Fungi_\r\nGenus: _Amanita_")
  end

  def test_validate_classification_4
    do_validate_classification_test(:Species, %(Kingdom: _Fungi_\r
      Genus: _Amanita_),
      "Kingdom: _Fungi_\r\nGenus: _Amanita_")
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
    do_validate_classification_test(:Species, "Genus: Amanita", "Genus: _Amanita_")
  end

  def test_validate_classification_9
    do_validate_classification_test(:Queendom, "Genus: Amanita", false)
  end

  def test_validate_classification_10
    do_validate_classification_test(:Species, "", "")
  end

  def test_validate_classification_11
    do_validate_classification_test(:Species, nil, nil)
  end

  # def dump_list_of_names(list)
  #   for n in list do
  #     print "id=#{n.id}, text_name='#{n.text_name}', author='#{n.author}'\n"
  #   end
  # end

  # ------------------------------
  #  Test ancestors and parents.
  # ------------------------------

  def test_ancestors_1
    assert_name_list_equal([names(:agaricus)], names(:agaricus_campestris).all_parents)
    assert_name_list_equal([names(:agaricus)], names(:agaricus_campestris).parents)
    assert_name_list_equal([], names(:agaricus_campestris).children)
    assert_name_list_equal([], names(:agaricus).all_parents)
    assert_name_list_equal([], names(:agaricus).parents)
    assert_name_list_equal([
      names(:agaricus_campestras),
      names(:agaricus_campestris),
      names(:agaricus_campestros),
      names(:agaricus_campestrus)
    ], names(:agaricus).children)
  end

  def test_ancestors_2
    # (use Petigera instead of Peltigera because it has no classification string)
    p = names(:petigera)
    assert_name_list_equal([], p.all_parents)
    assert_name_list_equal([], p.children)

    pc   = create_test_name('Petigera canina (L.) Willd.')
    pcr  = create_test_name('Petigera canina var. rufescens (Weiss) Mudd')
    pcri = create_test_name('Petigera canina var. rufescens f. innovans (Körber) J. W. Thomson')
    pcs  = create_test_name('Petigera canina var. spuria (Ach.) Schaerer')

    pa   = create_test_name('Petigera aphthosa (L.) Willd.')
    pac  = create_test_name('Petigera aphthosa f. complicata (Th. Fr.) Zahlbr.')
    pav  = create_test_name('Petigera aphthosa var. variolosa A. Massal.')

    pp   = create_test_name('Petigera polydactylon (Necker) Hoffm')
    pp2  = create_test_name('Petigera polydactylon (Bogus) Author')
    pph  = create_test_name('Petigera polydactylon var. hymenina (Ach.) Flotow')
    ppn  = create_test_name('Petigera polydactylon var. neopolydactyla Gyelnik')

    assert_name_list_equal([pa, pc, pp, pp2], p.children)
    assert_name_list_equal([pcr, pcs], pc.children)
    assert_name_list_equal([pcri], pcr.children)
    assert_name_list_equal([pac, pav], pa.children)
    assert_name_list_equal([pph, ppn], pp.children)

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
    assert_name_list_equal([pp2, pp], pph.parents)
    assert_name_list_equal([pp2, pp], ppn.parents)

    # Try it again if we clear the misspelling flag.
    p.correct_spelling = nil
    p.save

    assert_name_list_equal([p], pc.all_parents)
    assert_name_list_equal([pc, p], pcr.all_parents)
    assert_name_list_equal([pcr, pc, p], pcri.all_parents)
    assert_name_list_equal([pc, p], pcs.all_parents)
    assert_name_list_equal([p], pa.all_parents)
    assert_name_list_equal([pa, p], pac.all_parents)
    assert_name_list_equal([pa, p], pav.all_parents)
    assert_name_list_equal([p], pp.all_parents)
    assert_name_list_equal([p], pp2.all_parents)
    assert_name_list_equal([pp, p], pph.all_parents)
    assert_name_list_equal([pp, p], ppn.all_parents)

    assert_name_list_equal([p], pc.parents)
    assert_name_list_equal([pc], pcr.parents)
    assert_name_list_equal([pcr], pcri.parents)
    assert_name_list_equal([pc], pcs.parents)
    assert_name_list_equal([p], pa.parents)
    assert_name_list_equal([pa], pac.parents)
    assert_name_list_equal([pa], pav.parents)
    assert_name_list_equal([p], pp.parents)
    assert_name_list_equal([pp2, pp], pph.parents)
    assert_name_list_equal([pp2, pp], ppn.parents)

    pp2.change_deprecated(true)
    pp2.save

    assert_name_list_equal([pa, pc, pp, pp2], p.children)
    assert_name_list_equal([pp, p], pph.all_parents)
    assert_name_list_equal([pp, p], ppn.all_parents)
    assert_name_list_equal([pp], pph.parents)
    assert_name_list_equal([pp], ppn.parents)

    pp.change_deprecated(true)
    pp.save

    assert_name_list_equal([pa, pc, pp, pp2], p.children)
    assert_name_list_equal([pp, p], pph.all_parents)
    assert_name_list_equal([pp, p], ppn.all_parents)
    assert_name_list_equal([pp2, pp], pph.parents)
    assert_name_list_equal([pp2, pp], ppn.parents)
  end

  def test_ancestors_3
    kng = names(:fungi)
    phy = create_test_name('Ascomycota', :Phylum)
    cls = create_test_name('Ascomycetes', :Class)
    ord = create_test_name('Lecanorales', :Order)
    fam = create_test_name('Peltigeraceae', :Family)
    gen = names(:peltigera)
    spc = create_test_name('Peltigera canina (L.) Willd.')
    ssp = create_test_name('Peltigera canina ssp. bogus (Bugs) Bunny')
    var = create_test_name('Peltigera canina ssp. bogus var. rufescens (Weiss) Mudd')
    frm = create_test_name('Peltigera canina ssp. bogus var. rufescens f. innovans (Körber) J. W. Thomson')

    assert_name_list_equal([], kng.all_parents)
    assert_name_list_equal([kng], phy.all_parents)
    assert_name_list_equal([phy, kng], cls.all_parents)
    assert_name_list_equal([cls, phy, kng], ord.all_parents)
    assert_name_list_equal([ord, cls, phy, kng], fam.all_parents)
    assert_name_list_equal([fam, ord, cls, phy, kng], gen.all_parents)
    assert_name_list_equal([gen, fam, ord, cls, phy, kng], spc.all_parents)
    assert_name_list_equal([spc, gen, fam, ord, cls, phy, kng], ssp.all_parents)
    assert_name_list_equal([ssp, spc, gen, fam, ord, cls, phy, kng], var.all_parents)
    assert_name_list_equal([var, ssp, spc, gen, fam, ord, cls, phy, kng], frm.all_parents)

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

    assert_name_list_equal([phy], kng.children)
    assert_name_list_equal([cls], phy.children)
    assert_name_list_equal([ord], cls.children)
    assert_name_list_equal([fam], ord.children)
    assert_name_list_equal([gen], fam.children)
    assert_name_list_equal([spc], gen.children)
    assert_name_list_equal([ssp], spc.children)
    assert_name_list_equal([var], ssp.children)
    assert_name_list_equal([frm], var.children)
    assert_name_list_equal([],    frm.children)

    assert_name_list_equal([phy,cls,ord,fam,gen,spc,ssp,var,frm], kng.all_children)
    assert_name_list_equal([cls,ord,fam,gen,spc,ssp,var,frm], phy.all_children)
    assert_name_list_equal([ord,fam,gen,spc,ssp,var,frm], cls.all_children)
    assert_name_list_equal([fam,gen,spc,ssp,var,frm], ord.all_children)
    assert_name_list_equal([gen,spc,ssp,var,frm], fam.all_children)
    assert_name_list_equal([spc,ssp,var,frm], gen.all_children)
    assert_name_list_equal([ssp, var, frm], spc.all_children)
    assert_name_list_equal([var, frm], ssp.all_children)
    assert_name_list_equal([frm], var.all_children)
    assert_name_list_equal([], frm.all_children)
  end

  # --------------------------------------
  #  Test email notification heuristics.
  # --------------------------------------

  def test_email_notification
    name = names(:peltigera)
    desc = name_descriptions(:peltigera_desc)

    @rolf.email_names_admin    = false
    @rolf.email_names_author   = true
    @rolf.email_names_editor   = true
    @rolf.email_names_reviewer = true
    @rolf.email_names_all      = false
    @rolf.save

    @mary.email_names_admin    = false
    @mary.email_names_author   = true
    @mary.email_names_editor   = false
    @mary.email_names_reviewer = false
    @mary.email_names_all      = false
    @mary.save

    @dick.email_names_admin    = false
    @dick.email_names_author   = false
    @dick.email_names_editor   = false
    @dick.email_names_reviewer = false
    @dick.email_names_all      = false
    @dick.save

    @katrina.email_names_admin    = false
    @katrina.email_names_author   = true
    @katrina.email_names_editor   = true
    @katrina.email_names_reviewer = true
    @katrina.email_names_all      = true
    @katrina.save

    # Start with no reviewers, editors or authors.
    User.current = nil
    desc.gen_desc = ''
    desc.review_status = :unreviewed;
    desc.reviewer = nil;
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
    assert_equal(nil, desc.reviewer_id)

    # email types:  author  editor  review  all     interest
    # 1 Rolf:       x       x       x       .       .
    # 2 Mary:       x       .       .       .       .
    # 3 Dick:       .       .       .       .       .
    # 4 Katrina:    x       x       x       x       .
    # Authors: --        editors: --         reviewer: -- (unreviewed)
    # Rolf erases notes: notify Katrina (all), Rolf becomes editor.
    User.current = @rolf
    desc.reload
    desc.classification = ''
    desc.gen_desc = ''
    desc.diag_desc = ''
    desc.distribution = ''
    desc.habitat = ''
    desc.look_alikes = ''
    desc.uses = ''
    desc.save
    assert_equal(description_version + 1, desc.version)
    assert_equal(0, desc.authors.length)
    assert_equal(1, desc.editors.length)
    assert_equal(nil, desc.reviewer_id)
    assert_equal(@rolf, desc.editors.first)
    assert_equal(1, QueuedEmail.count)
    assert_email(0,
      :flavor        => 'QueuedEmail::NameChange',
      :from          => @rolf,
      :to            => @katrina,
      :name          => name.id,
      :description   => desc.id,
      :old_name_version => name.version,
      :new_name_version => name.version,
      :old_description_version => desc.version-1,
      :new_description_version => desc.version,
      :review_status => 'no_change'
    )

    # Katrina wisely reconsiders requesting notifications of all name changes.
    @katrina.email_names_all = false;
    @katrina.save

    # email types:  author  editor  review  all     interest
    # 1 Rolf:       x       x       x       .       .
    # 2 Mary:       x       .       .       .       .
    # 3 Dick:       .       .       .       .       .
    # 4 Katrina:    x       x       x       .       .
    # Authors: --        editors: Rolf       reviewer: -- (unreviewed)
    # Mary writes gen_desc: notify Rolf (editor), Mary becomes author.
    User.current = @mary
    desc.reload
    desc.gen_desc = "Mary wrote this."
    desc.save
    assert_equal(description_version + 2, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(1, desc.editors.length)
    assert_equal(nil, desc.reviewer_id)
    assert_equal(@mary, desc.authors.first)
    assert_equal(@rolf, desc.editors.first)
    assert_equal(2, QueuedEmail.count)
    assert_email(1,
      :flavor        => 'QueuedEmail::NameChange',
      :from          => @mary,
      :to            => @rolf,
      :name          => name.id,
      :description   => desc.id,
      :old_name_version => name.version,
      :new_name_version => name.version,
      :old_description_version => desc.version-1,
      :new_description_version => desc.version,
      :review_status => 'no_change'
    )

    # Rolf doesn't want to be notified if people change names he's edited.
    @rolf.email_names_editor = false
    @rolf.save

    # email types:  author  editor  review  all     interest
    # 1 Rolf:       x       .       x       .       .
    # 2 Mary:       x       .       .       .       .
    # 3 Dick:       .       .       .       .       .
    # 4 Katrina:    x       x       x       .       .
    # Authors: Mary      editors: Rolf       reviewer: -- (unreviewed)
    # Dick changes uses: notify Mary (author); Dick becomes editor.
    User.current = @dick
    desc.reload
    desc.uses = "Something more new."
    desc.save
    assert_equal(description_version + 3, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal(nil, desc.reviewer_id)
    assert_equal(@mary, desc.authors.first)
    assert_equal([@rolf.id, @dick.id], desc.editors.map(&:id).sort)
    assert_equal(3, QueuedEmail.count)
    assert_email(2,
      :flavor        => 'QueuedEmail::NameChange',
      :from          => @dick,
      :to            => @mary,
      :name          => name.id,
      :description   => desc.id,
      :old_name_version => name.version,
      :new_name_version => name.version,
      :old_description_version => desc.version-1,
      :new_description_version => desc.version,
      :review_status => 'no_change'
    )

    # Mary opts out of author emails, add Katrina as new author.
    desc.add_author(@katrina)
    @mary.email_names_author = false
    @mary.save

    # email types:  author  editor  review  all     interest
    # 1 Rolf:       x       .       x       .       .
    # 2 Mary:       .       .       .       .       .
    # 3 Dick:       .       .       .       .       .
    # 4 Katrina:    x       x       x       .       .
    # Authors: Mary,Katrina   editors: Rolf,Dick   reviewer: -- (unreviewed)
    # Rolf reviews name: notify Katrina (author), Rolf becomes reviewer.
    User.current = @rolf
    desc.reload
    desc.update_review_status(:inaccurate)
    assert_equal(description_version + 3, desc.version)
    assert_equal(2, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal(@rolf.id, desc.reviewer_id)
    assert_equal([@mary.id, @katrina.id], desc.authors.map(&:id).sort)
    assert_equal([@rolf.id, @dick.id], desc.editors.map(&:id).sort)
    assert_equal(4, QueuedEmail.count)
    assert_email(3,
      :flavor        => 'QueuedEmail::NameChange',
      :from          => @rolf,
      :to            => @katrina,
      :name          => name.id,
      :description   => desc.id,
      :old_name_version => name.version,
      :new_name_version => name.version,
      :old_description_version => desc.version,
      :new_description_version => desc.version,
      :review_status => 'inaccurate'
    )

    # Have Katrina express disinterest.
    Interest.create(:object => name, :user => @katrina, :state => false)

    # email types:  author  editor  review  all     interest
    # 1 Rolf:       x       .       x       .       .
    # 2 Mary:       .       .       .       .       .
    # 3 Dick:       .       .       .       .       .
    # 4 Katrina:    x       x       x       .       no
    # Authors: Mary,Katrina   editors: Rolf,Dick   reviewer: Rolf (inaccurate)
    # Dick changes look-alikes: notify Rolf (reviewer), clear review status
    User.current = @dick
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
    assert_equal(nil, desc.reviewer_id)
    assert_equal([@mary.id, @katrina.id], desc.authors.map(&:id).sort)
    assert_equal([@rolf.id, @dick.id], desc.editors.map(&:id).sort)
    assert_equal(5, QueuedEmail.count)
    assert_email(4,
      :flavor        => 'QueuedEmail::NameChange',
      :from          => @dick,
      :to            => @rolf,
      :name          => name.id,
      :description   => desc.id,
      :old_name_version => name.version,
      :new_name_version => name.version,
      :old_description_version => desc.version-1,
      :new_description_version => desc.version,
      :review_status => 'unreviewed'
    )

    # Mary expresses interest.
    Interest.create(:object => name, :user => @mary, :state => true)

    # email types:  author  editor  review  all     interest
    # 1 Rolf:       x       .       x       .       .
    # 2 Mary:       .       .       .       .       yes
    # 3 Dick:       .       .       .       .       .
    # 4 Katrina:    x       x       x       .       no
    # Authors: Mary,Katrina   editors: Rolf,Dick   reviewer: Rolf (unreviewed)
    # Rolf changes 'uses': notify Mary (interest).
    User.current = @rolf
    name.reload
    name.citation = "Rolf added this."
    name.save
    assert_equal(name_version + 1, name.version)
    assert_equal(description_version + 4, desc.version)
    assert_equal(2, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal(nil, desc.reviewer_id)
    assert_equal([@mary.id, @katrina.id], desc.authors.map(&:id).sort)
    assert_equal([@rolf.id, @dick.id], desc.editors.map(&:id).sort)
    assert_equal(6, QueuedEmail.count)
    assert_email(5,
      :flavor        => 'QueuedEmail::NameChange',
      :from          => @rolf,
      :to            => @mary,
      :name          => name.id,
      :description   => 0,
      :old_name_version => name.version-1,
      :new_name_version => name.version,
      :old_description_version => 0,
      :new_description_version => 0,
      :review_status => 'no_change'
    )
  end

  def test_misspelling
    User.current = @rolf

    # Make sure deprecating a name doesn't clear misspelling stuff.
    names(:petigera).change_deprecated(true)
    assert(names(:petigera).is_misspelling?)
    assert_equal(names(:peltigera), names(:petigera).correct_spelling)

    # Make sure approving a name clears misspelling stuff.
    names(:petigera).change_deprecated(false)
    assert(!names(:petigera).is_misspelling?)
    assert_nil(names(:petigera).correct_spelling)

    # Coprinus comatus should normally end up in name primer.
    File.delete(NAME_PRIMER_CACHE_FILE) if File.exists?(NAME_PRIMER_CACHE_FILE)
    assert(!Name.primer.select {|n| n == 'Coprinus comatus'}.empty?)

    # Mark it as misspelled and see that it gets removed from the primer list.
    names(:coprinus_comatus).correct_spelling = names(:agaricus_campestris)
    names(:coprinus_comatus).change_deprecated(true)
    names(:coprinus_comatus).save
    File.delete(NAME_PRIMER_CACHE_FILE)
    assert(Name.primer.select {|n| n == 'Coprinus comatus'}.empty?)
  end
end
