require File.dirname(__FILE__) + '/../test_helper'

class NameTest < Test::Unit::TestCase
  fixtures :names
  fixtures :past_names
  fixtures :users
  fixtures :user_groups
  fixtures :user_groups_users

#   # Create new subspecies Coprinus comatus v. bogus and make sure it doesn't
#   # create a duplicate species if one already exists.
#   # Saw this bug 20080114 -JPH
#   def test_names_from_string
# 
#     # Coprinus comatus already has an author.
#     result = Name.names_from_string("Coprinus comatus v. bogus (With) Author")
#     assert_equal 3, result.length
#     assert_equal nil, result[0].id
#     assert_equal 2,   result[1].id
#     assert_equal nil, result[2].id
#     assert_equal "Coprinus", result[0].text_name
#     assert_equal "Coprinus comatus", result[1].text_name
#     assert_equal "Coprinus comatus var. bogus", result[2].text_name
#     assert_equal nil, result[0].author
#     assert_equal "(O.F. Müll.) Pers.", result[1].author
#     assert_equal "(With) Author", result[2].author
# 
#     # Conocybe filaris does not have an author.
#     result = Name.names_from_string("Conocybe filaris var bogus (With) Author")
#     assert_equal 3, result.length
#     assert_equal nil, result[0].id
#     assert_equal 4,   result[1].id
#     assert_equal nil, result[2].id
#     assert_equal "Conocybe", result[0].text_name
#     assert_equal "Conocybe filaris", result[1].text_name
#     assert_equal "Conocybe filaris var. bogus", result[2].text_name
#     assert_equal nil, result[0].author
#     assert_equal nil, result[1].author
#     assert_equal "(With) Author", result[2].author
# 
#     # Agaricus does not have an author.
#     result = Name.names_from_string("Agaricus L.")
#     assert_equal 1, result.length
#     assert_equal 18, result[0].id
#     assert_equal "Agaricus", result[0].text_name
#     assert_equal "L.", result[0].author
# 
#     # Agaricus does not have an author.
#     result = Name.names_from_string("Agaricus abra f. cadabra (With) Another Author")
#     assert_equal 3, result.length
#     assert_equal 18, result[0].id
#     assert_equal nil, result[1].id
#     assert_equal nil, result[2].id
#     assert_equal "Agaricus", result[0].text_name
#     assert_equal "Agaricus abra", result[1].text_name
#     assert_equal "Agaricus abra f. cadabra", result[2].text_name
#     assert_equal nil, result[0].author
#     assert_equal nil, result[1].author
#     assert_equal "(With) Another Author", result[2].author
#   end
# 
#   def do_name_parse_test(*args)
#     parse = Name.parse_name(args.shift)
#     assert_equal(args, parse)
#   end
# 
#   def test_name_parse_1
#     do_name_parse_test(
#       'Lecania ryaniana van den Boom',
#       'Lecania ryaniana',
#       '**__Lecania ryaniana__** van den Boom',
#       '**__Lecania ryaniana__** van den Boom',
#       'Lecania ryaniana van den Boom',
#       'Lecania',
#       :Species,
#       'van den Boom'
#     )
#   end
# 
#   def test_name_parse_2
#     do_name_parse_test(
#       'Lecidea sanguineoatra sens. Nyl',
#       'Lecidea sanguineoatra',
#       '**__Lecidea sanguineoatra__** sens. Nyl',
#       '**__Lecidea sanguineoatra__** sens. Nyl',
#       'Lecidea sanguineoatra sens. Nyl',
#       'Lecidea',
#       :Species,
#       'sens. Nyl'
#     )
#   end
# 
#   def test_name_parse_3
#     do_name_parse_test(
#       'Acarospora squamulosa sensu Th. Fr.',
#       'Acarospora squamulosa',
#       '**__Acarospora squamulosa__** sensu Th. Fr.',
#       '**__Acarospora squamulosa__** sensu Th. Fr.',
#       'Acarospora squamulosa sensu Th. Fr.',
#       'Acarospora',
#       :Species,
#       'sensu Th. Fr.'
#     )
#   end
# 
#   def test_name_parse_4
#     do_name_parse_test(
#       'Cladina portentosa subsp. pacifica f. decolorans auct.',
#       'Cladina portentosa subsp. pacifica f. decolorans',
#       '**__Cladina portentosa__** subsp. **__pacifica__** f. **__decolorans__** auct.',
#       '**__Cladina portentosa__** subsp. **__pacifica__** f. **__decolorans__** auct.',
#       'Cladina portentosa subsp. pacifica f. decolorans auct.',
#       'Cladina portentosa subsp. pacifica',
#       :Form ,
#       'auct.'
#     )
#   end
# 
#   def test_name_parse_5
#     do_name_parse_test(
#       'Japewia tornoënsis Somloë',
#       'Japewia tornoensis',
#       '**__Japewia tornoënsis__** Somloë',
#       '**__Japewia tornoënsis__** Somloë',
#       'Japewia tornoensis Somloë',
#       'Japewia',
#       :Species,
#       'Somloë'
#     )
#   end
# 
#   def test_name_parse_6
#     do_name_parse_test(
#       'Micarea globularis "(Ach. ex Nyl.) Hedl."',
#       'Micarea globularis',
#       '**__Micarea globularis__** "(Ach. ex Nyl.) Hedl."',
#       '**__Micarea globularis__** "(Ach. ex Nyl.) Hedl."',
#       'Micarea globularis "(Ach. ex Nyl.) Hedl."',
#       'Micarea',
#       :Species,
#       '"(Ach. ex Nyl.) Hedl."'
#     )
#   end
# 
#   def test_name_parse_7
#     do_name_parse_test(
#       'Synechoblastus aggregatus ("Ach.") Th. Fr.',
#       'Synechoblastus aggregatus',
#       '**__Synechoblastus aggregatus__** ("Ach.") Th. Fr.',
#       '**__Synechoblastus aggregatus__** ("Ach.") Th. Fr.',
#       'Synechoblastus aggregatus ("Ach.") Th. Fr.',
#       'Synechoblastus',
#       :Species,
#       '("Ach.") Th. Fr.'
#     )
#   end
# 
#   def test_name_parse_8
#     do_name_parse_test(
#       '"Toninia"',
#       '"Toninia"',
#       '**__"Toninia"__**',
#       '**__"Toninia" sp.__**',
#       '"Toninia" sp.',
#       nil,
#       :Genus,
#       nil
#     )
#   end
# 
#   def test_name_parse_9
#     do_name_parse_test(
#       '"Toninia" sp.',
#       '"Toninia"',
#       '**__"Toninia"__**',
#       '**__"Toninia" sp.__**',
#       '"Toninia" sp.',
#       nil,
#       :Genus,
#       nil
#     )
#   end
# 
#   def test_name_parse_10
#     do_name_parse_test(
#       '"Toninia" squalescens',
#       '"Toninia" squalescens',
#       '**__"Toninia" squalescens__**',
#       '**__"Toninia" squalescens__**',
#       '"Toninia" squalescens',
#       '"Toninia"',
#       :Species,
#       nil
#     )
#   end
# 
#   def test_name_parse_11
#     do_name_parse_test(
#       'Anaptychia "leucomelaena" auct.',
#       'Anaptychia "leucomelaena"',
#       '**__Anaptychia "leucomelaena"__** auct.',
#       '**__Anaptychia "leucomelaena"__** auct.',
#       'Anaptychia "leucomelaena" auct.',
#       'Anaptychia',
#       :Species,
#       'auct.'
#     )
#   end
# 
#   def test_name_parse_12
#     do_name_parse_test(
#       'Anema',
#       'Anema',
#       '**__Anema__**',
#       '**__Anema sp.__**',
#       'Anema sp.',
#       nil,
#       :Genus,
#       nil
#     )
#   end
# 
#   def test_name_parse_13
#     do_name_parse_test(
#       'Anema sp',
#       'Anema',
#       '**__Anema__**',
#       '**__Anema sp.__**',
#       'Anema sp.',
#       nil,
#       :Genus,
#       nil
#     )
#   end
# 
#   def test_name_parse_14
#     do_name_parse_test(
#       'Anema sp.',
#       'Anema',
#       '**__Anema__**',
#       '**__Anema sp.__**',
#       'Anema sp.',
#       nil,
#       :Genus,
#       nil
#     )
#   end
# 
#   def test_name_parse_15
#     do_name_parse_test(
#       'Anema Nyl. ex Forss.',
#       'Anema',
#       '**__Anema__** Nyl. ex Forss.',
#       '**__Anema sp.__** Nyl. ex Forss.',
#       'Anema sp. Nyl. ex Forss.',
#       nil,
#       :Genus,
#       'Nyl. ex Forss.'
#     )
#   end
# 
#   def test_name_parse_16
#     do_name_parse_test(
#       'Anema sp Nyl. ex Forss.',
#       'Anema',
#       '**__Anema__** Nyl. ex Forss.',
#       '**__Anema sp.__** Nyl. ex Forss.',
#       'Anema sp. Nyl. ex Forss.',
#       nil,
#       :Genus,
#       'Nyl. ex Forss.'
#     )
#   end
# 
#   def test_name_parse_17
#     do_name_parse_test(
#       'Anema sp. Nyl. ex Forss.',
#       'Anema',
#       '**__Anema__** Nyl. ex Forss.',
#       '**__Anema sp.__** Nyl. ex Forss.',
#       'Anema sp. Nyl. ex Forss.',
#       nil,
#       :Genus,
#       'Nyl. ex Forss.'
#     )
#   end
# 
#   def test_name_parse_18
#     do_name_parse_test(
#       'Japewia tornoënsis var. tornoënsis',
#       'Japewia tornoensis var. tornoensis',
#       '**__Japewia tornoënsis__** var. **__tornoënsis__**',
#       '**__Japewia tornoënsis__** var. **__tornoënsis__**',
#       'Japewia tornoensis var. tornoensis',
#       'Japewia tornoënsis',
#       :Variety,
#       nil
#     )
#   end
# 
#   def test_name_parse_19
#     do_name_parse_test(
#       'Does this ssp. ever var. happen f. for Real?',
#       'Does this subsp. ever var. happen f. for',
#       '**__Does this__** subsp. **__ever__** var. **__happen__** f. **__for__** Real?',
#       '**__Does this__** subsp. **__ever__** var. **__happen__** f. **__for__** Real?',
#       'Does this subsp. ever var. happen f. for Real?',
#       'Does this ssp. ever var. happen',
#       :Form,
#       'Real?'
#     )
#   end
# 
#   def test_name_parse_20
#     do_name_parse_test(
#       'Boletus  rex-veris Arora & Simonini',
#       'Boletus rex-veris',
#       '**__Boletus rex-veris__** Arora & Simonini',
#       '**__Boletus rex-veris__** Arora & Simonini',
#       'Boletus rex-veris Arora & Simonini',
#       'Boletus',
#       :Species,
#       'Arora & Simonini'
#     )
#   end
# 
#   def do_parse_classification_test(text, expected)
#     begin
#       parse = Name.parse_classification(text)
#       assert_equal(expected, parse)
#     rescue RuntimeError => err
#       raise err if expected
#     end
#   end
# 
#   def test_parse_classification_1
#     do_parse_classification_test("Kingdom: Fungi", [[:Kingdom, "Fungi"]])
#   end
# 
#   def test_parse_classification_2
#     do_parse_classification_test(%(Kingdom: Fungi\r
#       Phylum: Basidiomycota\r
#       Class: Basidiomycetes\r
#       Order: Agaricales\r
#       Family: Amanitaceae\r
#       Genus: Amanita),
#       [[:Kingdom, "Fungi"],
#        [:Phylum, "Basidiomycota"],
#        [:Class, "Basidiomycetes"],
#        [:Order, "Agaricales"],
#        [:Family, "Amanitaceae"],
#        [:Genus, "Amanita"]
#       ])
#   end
# 
#   def test_parse_classification_3
#     do_parse_classification_test(%(Kingdom: Fungi\r
#       \r
#       Genus: Amanita),
#       [[:Kingdom, "Fungi"],
#        [:Genus, "Amanita"]
#       ])
#   end
# 
#   def test_parse_classification_4
#     do_parse_classification_test(%(Kingdom: _Fungi_\r
#       Genus: _Amanita_),
#       [[:Kingdom, "Fungi"],
#        [:Genus, "Amanita"]
#       ])
#   end
# 
#   def test_parse_classification_5
#     do_parse_classification_test("Queendom: Fungi", [[:Queendom, "Fungi"]])
#   end
# 
#   def test_parse_classification_6
#     do_parse_classification_test("Junk text", false)
#   end
# 
#   def test_parse_classification_7
#     do_parse_classification_test(%(Kingdom: Fungi\r
#       Junk text\r
#       Genus: Amanita), false)
#   end
# 
#   def do_validate_classification_test(rank, text, expected)
#     begin
#       result = Name.validate_classification(rank, text)
#       assert_equal(expected, result)
#     rescue RuntimeError => err
#       raise err if expected
#     end
#   end
# 
#   def test_validate_classification_1
#     do_validate_classification_test(:Species, "Kingdom: Fungi", "Kingdom: _Fungi_")
#   end
# 
#   def test_validate_classification_2
#     do_validate_classification_test(:Species, %(Kingdom: Fungi\r
#       Phylum: Basidiomycota\r
#       Class: Basidiomycetes\r
#       Order: Agaricales\r
#       Family: Amanitaceae\r
#       Genus: Amanita),
#       "Kingdom: _Fungi_\r\nPhylum: _Basidiomycota_\r\nClass: _Basidiomycetes_\r\n" +
#       "Order: _Agaricales_\r\nFamily: _Amanitaceae_\r\nGenus: _Amanita_")
#   end
# 
#   def test_validate_classification_3
#     do_validate_classification_test(:Species, %(Kingdom: Fungi\r
#       \r
#       Genus: Amanita),
#       "Kingdom: _Fungi_\r\nGenus: _Amanita_")
#   end
# 
#   def test_validate_classification_4
#     do_validate_classification_test(:Species, %(Kingdom: _Fungi_\r
#       Genus: _Amanita_),
#       "Kingdom: _Fungi_\r\nGenus: _Amanita_")
#   end
# 
#   def test_validate_classification_5
#     do_validate_classification_test(:Species, "Queendom: Fungi", false)
#   end
# 
#   def test_validate_classification_6
#     do_validate_classification_test(:Species, "Junk text", false)
#   end
# 
#   def test_validate_classification_7
#     do_validate_classification_test(:Genus, "Species: calyptroderma", false)
#   end
# 
#   def test_validate_classification_8
#     do_validate_classification_test(:Species, "Genus: Amanita", "Genus: _Amanita_")
#   end
# 
#   def test_validate_classification_9
#     do_validate_classification_test(:Queendom, "Genus: Amanita", false)
#   end
# 
#   def test_validate_classification_10
#     do_validate_classification_test(:Species, "", "")
#   end
# 
#   def test_validate_classification_11
#     do_validate_classification_test(:Species, nil, nil)
#   end
# 
#   # def dump_list_of_names(list)
#   #   for n in list do
#   #     print "id=#{n.id}, text_name='#{n.text_name}', author='#{n.author}'\n"
#   #   end
#   # end

  # --------------------------------------
  #  Test email notification heuristics.
  # --------------------------------------

  def test_email_notification
    QueuedEmail.queue_emails(true)
    emails = QueuedEmail.find(:all).length
    version = @peltigera.version

    # No authors on @peltigera yet.
    assert_equal(0, @peltigera.authors.length)
    @peltigera.gen_desc = ''
    @peltigera.save_if_changed(@rolf, :log_name_updated, { :user => 'rolf' }, Time.now, true)
    assert_equal(version + 1, @peltigera.version)
    assert_equal(0, @peltigera.authors.length)
    assert_equal(emails, QueuedEmail.find(:all).length)

    # Now have mary become author.  (Still no emails.)
    @peltigera.gen_desc = "Mary wrote this."
    @peltigera.save_if_changed(@mary, :log_name_updated, { :user => 'mary' }, Time.now, true)
    assert_equal(version + 2, @peltigera.version)
    assert_equal(1, @peltigera.authors.length)
    assert_equal(@mary, @peltigera.authors.first)
    assert_equal(emails, QueuedEmail.find(:all).length)

    # Now when rolf changes the citation mary should get notified.
    @peltigera.citation = "Something more new."
    @peltigera.save_if_changed(@rolf, :log_name_updated, { :user => 'rolf' }, Time.now, true)
    assert_equal(version + 3, @peltigera.version)
    assert_equal(emails + 1, QueuedEmail.find(:all).length)
    assert_email(emails, {
        :flavor        => :name_change,
        :from          => @rolf,
        :to            => @mary,
        :name          => @peltigera.id,
        :old_version   => @peltigera.version-1,
        :new_version   => @peltigera.version,
        :review_status => 'no_change',
    })

    # Have mary express disinterest in it, dick express interest, and add katrina
    # as another author, THEN have rolf tweak the review status.
    Interest.new(:object => @peltigera, :user => @mary, :state => false).save
    Interest.new(:object => @peltigera, :user => @dick, :state => true).save
    @peltigera.add_author(@katrina)
    @peltigera.update_review_status(:inaccurate, @rolf)
    assert_equal(version + 3, @peltigera.version)
    assert_equal(2, @peltigera.authors.length)
    assert_equal(@mary, @peltigera.authors.first)
    assert_equal(@katrina, @peltigera.authors.last)
    assert_equal(emails + 3, QueuedEmail.find(:all).length)
    assert_email(emails + 1, {
        :flavor        => :name_change,
        :from          => @rolf,
        :to            => @katrina,
        :name          => @peltigera.id,
        :old_version   => @peltigera.version,
        :new_version   => @peltigera.version,
        :review_status => 'inaccurate',
    })
    assert_email(emails + 2, {
        :flavor        => :name_change,
        :from          => @rolf,
        :to            => @dick,
        :name          => @peltigera.id,
        :old_version   => @peltigera.version,
        :new_version   => @peltigera.version,
        :review_status => 'inaccurate',
    })
  end
end
