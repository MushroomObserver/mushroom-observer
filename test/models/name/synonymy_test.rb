# frozen_string_literal: true

require("test_helper")

# Tests for Name::Synonymy (app/models/name/synonymy.rb)
class Name::SynonymyTest < UnitTestCase
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
      search_name: "Lepiota rhacodes (Vittad.) Quél.",
      display_name: "__Lepiota__ __rhacodes__ (Vittad.) Quél.",
      synonym: synonyms(:macrolepiota_rachodes_synonym),
      deprecated: true,
      rank: "Species", user: users(:rolf)
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
      search_name: "Agaricus rhacodes Vittad.",
      display_name: "__Agaricus__ __rhacodes__ Vittad.",
      synonym: synonyms(:chlorophyllum_rachodes_synonym),
      deprecated: true,
      rank: "Species", user: users(:rolf)
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
    less_observed_naming.update(created_at: 1.hour.from_now)
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
    later_proposed_naming.update(created_at: 1.hour.from_now)

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

  def test_multiple_synonyms
    name1 = names(:chlorophyllum_rachodes)
    name2 = names(:macrolepiota_rachodes)
    assert_not_equal(name1.synonym, name2.synonym)
    name1.merge_synonyms(name2)
    name1.reload
    name2.reload
    assert_equal(name1.synonym, name2.synonym)
  end
end
