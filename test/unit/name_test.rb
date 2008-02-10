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

  # def dump_list_of_names(list)
  #   for n in list do
  #     print "id=#{n.id}, text_name='#{n.text_name}', author='#{n.author}'\n"
  #   end
  # end
end
