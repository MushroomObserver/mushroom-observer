# frozen_string_literal: true

require("test_helper")

# Tests for Name::Spelling (app/models/name/spelling.rb)
class Name::SpellingTest < UnitTestCase
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

  # --------------------------------------
  #  Spelling
  # --------------------------------------

  def test_parent_if_parent_deprecated
    lepiota = names(:lepiota)
    lepiota.change_deprecated(true)
    lepiota.save
    assert_nil(Name.parent_if_parent_deprecated(rolf, "Agaricus campestris"))
    assert_nil(Name.parent_if_parent_deprecated(rolf,
                                                "Agaricus campestris ssp. foo"))
    assert_nil(
      Name.parent_if_parent_deprecated(rolf,
                                       "Agaricus campestris ssp. foo var. bar")
    )
    assert(Name.parent_if_parent_deprecated(rolf, "Lactarius alpigenes"))
    assert(Name.parent_if_parent_deprecated(rolf,
                                            "Lactarius alpigenes ssp. foo"))
    assert(
      Name.parent_if_parent_deprecated(rolf,
                                       "Lactarius alpigenes ssp. foo var. bar")
    )
    assert_nil(Name.parent_if_parent_deprecated(rolf, "Peltigera"))
    assert_nil(Name.parent_if_parent_deprecated(rolf, "Peltigera neckeri"))
    assert_nil(Name.parent_if_parent_deprecated(rolf,
                                                "Peltigera neckeri f. alba"))
    assert(Name.parent_if_parent_deprecated(rolf, "Lepiota"))
    assert(Name.parent_if_parent_deprecated(rolf, "Lepiota barsii"))
    assert(Name.parent_if_parent_deprecated(rolf, "Lepiota barsii f. alba"))
  end

  def test_names_from_synonymous_genera
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

    assert_obj_arrays_equal([a1],
                            Name.names_from_synonymous_genera(rolf,
                                                              "Lepiota testa"))
    assert_obj_arrays_equal([a1],
                            Name.names_from_synonymous_genera(rolf,
                                                              "Lepiota testus"))
    assert_obj_arrays_equal([a1],
                            Name.names_from_synonymous_genera(rolf,
                                                              "Lepiota testum"))
    assert_obj_arrays_equal([a3],
                            Name.names_from_synonymous_genera(rolf,
                                                              "Lepiota testii"))

    a1.change_deprecated(true)
    a1.save
    assert_obj_arrays_equal([a1, b1, c1],
                            Name.names_from_synonymous_genera(rolf,
                                                              "Lepiota testa"),
                            :sort)
  end

  def test_suggest_alternate_spelling
    genus1 = create_test_name("Lecanora")
    genus2 = create_test_name("Lecania")
    species1 = create_test_name("Lecanora galactina")
    species2 = create_test_name("Lecanora galactinula")
    species3 = create_test_name("Lecanora grantii")
    species4 = create_test_name("Lecanora grandis")
    species5 = create_test_name("Lecania grandis")

    assert_name_arrays_equal([genus1],
                             Name.guess_with_errors("Lecanora", 1))
    assert_name_arrays_equal([genus1, genus2],
                             Name.guess_with_errors("Lecanoa", 1), :sort)
    assert_name_arrays_equal([],
                             Name.guess_with_errors("Lecanroa", 1))
    assert_name_arrays_equal([genus1, genus2],
                             Name.guess_with_errors("Lecanroa", 2), :sort)
    assert_name_arrays_equal([genus1],
                             Name.guess_with_errors("Lecanosa", 1))
    assert_name_arrays_equal([genus1, genus2],
                             Name.guess_with_errors("Lecanosa", 2), :sort)
    assert_name_arrays_equal([genus1, genus2],
                             Name.guess_with_errors("Lecanroa", 3), :sort)
    assert_name_arrays_equal([genus1],
                             Name.guess_with_errors("Lacanora", 1))
    assert_name_arrays_equal([genus1],
                             Name.guess_with_errors("Lacanora", 2))
    assert_name_arrays_equal([genus1],
                             Name.guess_with_errors("Lacanora", 3))
    assert_name_arrays_equal([genus1],
                             Name.guess_word("", "Lacanora"))
    assert_name_arrays_equal([genus1, genus2],
                             Name.guess_word("", "Lecanroa"), :sort)

    assert_name_arrays_equal([species1, species2],
                             Name.guess_with_errors("Lecanora galactina", 1),
                             :sort)
    assert_name_arrays_equal([species3],
                             Name.guess_with_errors("Lecanora granti", 1))
    assert_name_arrays_equal([species3, species4],
                             Name.guess_with_errors("Lecanora granti", 2),
                             :sort)
    assert_name_arrays_equal([],
                             Name.guess_with_errors("Lecanora gran", 3))
    assert_name_arrays_equal([species3],
                             Name.guess_word("Lecanora", "granti"))

    assert_name_arrays_equal([names(:lecanorales), genus1],
                             Name.suggest_alternate_spellings("Lecanora"),
                             :sort)
    assert_name_arrays_equal([names(:lecanorales), genus1],
                             Name.suggest_alternate_spellings("Lecanora\\"),
                             :sort)
    assert_name_arrays_equal([genus1, genus2],
                             Name.suggest_alternate_spellings("Lecanoa"), :sort)
    assert_name_arrays_equal(
      [species3], Name.suggest_alternate_spellings("Lecanora granti")
    )
    assert_name_arrays_equal(
      [species3, species4],
      Name.suggest_alternate_spellings("Lecanora grandi"), :sort
    )
    assert_name_arrays_equal(
      [species4, species5],
      Name.suggest_alternate_spellings("Lecanoa grandis"), :sort
    )
  end

  def test_name_guessing
    # Not all the genera actually have records in our test database.
    Name.create_needed_names(rolf, "Agaricus")
    Name.create_needed_names(rolf, "Pluteus")
    Name.create_needed_names(rolf,
                             "Coprinus comatus subsp. bogus var. varietus")

    assert_name_suggestions("Agricus")
    assert_name_suggestions("Ptligera")
    assert_name_suggestions(" plutues _petastus  ")
    assert_name_suggestions("Coprinis comatis")
    assert_name_suggestions("Coprinis comatis Blah. Boggle")
    assert_name_suggestions("Coprinis comatis Blah. Boggle var. varitus")
  end

  def assert_name_suggestions(str)
    results = Name.suggest_alternate_spellings(str)
    assert(results.any?,
           "Couldn't suggest alternate spellings for #{str.inspect}.")
  end

  # The ":Fr" in this used to raise an ActiveRecord error because it was
  # interpreting it as a named variable.
  def test_guess_name_with_colon_in_pattern
    # Apparently assert_nothing_raised hides debug information but gives
    # nothing useful in return.
    Name.guess_with_errors("Crepidotus applanatus(Pers.:Fr.)Kummer", 1)
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
end
