# frozen_string_literal: true

require("test_helper")

# Tests for Name::Change (app/models/name/change.rb)
class Name::ChangeTest < UnitTestCase
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

  def test_misspelling
    # Make sure deprecating a name doesn't clear misspelling stuff.
    names(:petigera).change_deprecated(true)
    assert(names(:petigera).is_misspelling?)
    assert_equal(names(:peltigera), names(:petigera).correct_spelling)

    # Make sure approving a name clears misspelling stuff.
    names(:petigera).change_deprecated(false)
    assert_not(names(:petigera).is_misspelling?)
    assert_nil(names(:petigera).correct_spelling)
  end

  def test_changing_author_of_autonym
    name = create_test_name("Acarospora nodulosa var. nodulosa")
    assert_equal("Acarospora nodulosa var. nodulosa", name.text_name)
    assert_equal("Acarospora nodulosa var. nodulosa", name.search_name)
    assert_equal("Acarospora nodulosa  {6var.  !nodulosa", name.sort_name)
    assert_equal("**__Acarospora__** **__nodulosa__** var. **__nodulosa__**",
                 name.display_name)
    assert_equal("", name.author)

    name.change_author("(Dufour) Hue")
    assert_equal("Acarospora nodulosa var. nodulosa", name.text_name)
    assert_equal("Acarospora nodulosa var. nodulosa (Dufour) Hue",
                 name.search_name)
    assert_equal("Acarospora nodulosa  {6var.  !nodulosa  (Dufour) Hue",
                 name.sort_name)
    assert_equal(
      "**__Acarospora__** **__nodulosa__** (Dufour) Hue var. **__nodulosa__**",
      name.display_name
    )
    assert_equal("(Dufour) Hue", name.author)

    name.change_author("Ach.")
    assert_equal("Acarospora nodulosa var. nodulosa", name.text_name)
    assert_equal("Acarospora nodulosa var. nodulosa Ach.", name.search_name)
    assert_equal("Acarospora nodulosa  {6var.  !nodulosa  Ach.", name.sort_name)
    assert_equal(
      "**__Acarospora__** **__nodulosa__** Ach. var. **__nodulosa__**",
      name.display_name
    )
    assert_equal("Ach.", name.author)
  end

  # `change_text_name` raises when it can't find-or-create a parent Name
  # for the parsed name's genus. Force that failure by stubbing
  # `find_or_create_name_and_parents` to return an array whose last
  # element is nil, mirroring what `find_or_create_parsed_name` returns
  # when it can't resolve an ambiguous match.
  def test_change_text_name_raises_when_parent_creation_fails
    name = names(:coprinus_comatus)
    # "Zzyzxomyces" isn't a fixture, so the parent-lookup guard
    # (`!Name.find_by(text_name: parse.parent_name)`) falls through to
    # `find_or_create_name_and_parents`.
    Name.stub(:find_or_create_name_and_parents, [nil]) do
      assert_raises(RuntimeError) do
        name.change_text_name(rolf, "Zzyzxomyces weirdii", "Foo", "Species")
      end
    end
  end

  def test_mark_misspelled
    # Make sure target name has synonyms.
    syn = Synonym.create
    Name.where(Name[:text_name].matches("Agaricus camp%")).
      update_all(synonym_id: syn.id)

    good = names(:agaricus_campestris)
    bad  = names(:coprinus_comatus)
    old_obs = Observation.where(name: bad)
    old_synonym_count = good.synonyms.count

    bad.mark_misspelled(nil, good, :save)
    good.reload
    bad.reload

    assert_true(bad.deprecated)
    assert_false(good.deprecated)
    assert(bad.display_name.starts_with?("__"))
    assert(good.display_name.starts_with?("**__"))
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
    bad.clear_misspelled(rolf, :save)
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
end
