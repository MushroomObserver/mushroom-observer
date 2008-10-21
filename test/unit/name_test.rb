require File.dirname(__FILE__) + '/../test_helper'

class NameTest < Test::Unit::TestCase
  fixtures :names

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

  def do_name_parse_test(*args)
    parse = Name.parse_name(args.shift)
    assert_equal(args, parse)
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

  # def dump_list_of_names(list)
  #   for n in list do
  #     print "id=#{n.id}, text_name='#{n.text_name}', author='#{n.author}'\n"
  #   end
  # end
end
