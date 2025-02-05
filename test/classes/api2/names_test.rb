# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::NamesTest < UnitTestCase
  include API2Extensions

  def test_basic_name_get
    do_basic_get_test(Name)
  end

  # --------------------------
  #  :section: Name Requests
  # --------------------------

  def name_get_params
    @name_get_params ||= { method: :get, action: :name }
  end

  def test_getting_names
    name = Name.with_correct_spelling.sample
    assert_api_pass(name_get_params.merge(id: name.id))
    assert_api_results([name])
  end

  def test_getting_names_year
    names = Name.with_correct_spelling.where(Name[:created_at].year.eq(2008))
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(created_at: "2008"))
    assert_api_results(names)
  end

  def test_getting_names_date
    names = Name.with_correct_spelling.updated_on("2008-09-05")
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(updated_at: "2008-09-05"))
    assert_api_results(names)
  end

  def test_getting_names_user
    names = Name.with_correct_spelling.where(user: mary)
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(user: "mary"))
    assert_api_results(names)
  end

  # FIXME: IMO this test should fail. This should be considered an invalid use
  # of the API `name` param (which corresponds to Query `names`). `names` wants
  # an array of ids, with lookup-by-string as a last resort. This API query
  # should instead have been sent as two queries: a pattern search returning
  # ids, and then a query for subtaxa via an id.
  # def test_getting_names_name_with_two_versions
  #   names = Name.with_correct_spelling.where(text_name: "Lentinellus ursinus")
  #   assert_not_empty(names)
  #   assert_api_fail(name_get_params.merge(name: "Lentinellus ursinus"))
  #   assert_api_pass(
  #     name_get_params.merge(
  #       name: "Lentinellus ursinus Kühner, Lentinellus ursinus Kuhner"
  #     )
  #   )
  #   assert_api_results(names)
  # end

  def test_getting_names_name_with_synonyms
    names = names(:lactarius_alpinus).synonyms.sort_by(&:id).
            reject(&:correct_spelling_id)
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(synonyms_of: "Lactarius alpinus"))
    assert_api_results(names)
    assert_api_pass(name_get_params.merge(name: "Lactarius alpinus",
                                          include_synonyms: "yes"))
    assert_api_results(names)
  end

  def test_getting_names_name_includes_subtaxa
    names = Name.with_correct_spelling.classification_contains("Fungi").
            map do |n|
      genus = n.text_name.split.first
      Name.where(Name[:text_name].matches("#{genus} %")) + [n]
    end.flatten.uniq.sort_by(&:id)
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(children_of: "Fungi"))
    assert_api_results(names)
    assert_api_pass(name_get_params.merge(name: "Fungi",
                                          include_subtaxa: "yes"))
    assert_api_results(names << names(:fungi))
  end

  def test_getting_names_deprecated
    names = Name.with_correct_spelling.deprecated
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(is_deprecated: "true"))
    assert_api_results(names)
  end

  def test_getting_names_misspellings
    names = Name.updated_on("2009-10-12")
    goods = names.reject(&:correct_spelling_id)
    bads  = names.select(&:correct_spelling_id)
    assert_not_empty(names)
    assert_not_empty(goods)
    assert_not_empty(bads)
    assert_api_pass(name_get_params.merge(updated_at: "20091012",
                                          misspellings: :either))
    assert_api_results(names)
    assert_api_pass(name_get_params.merge(updated_at: "20091012",
                                          misspellings: :only))
    assert_api_results(bads)
    assert_api_pass(name_get_params.merge(updated_at: "20091012",
                                          misspellings: :no))
    assert_api_results(goods)
    assert_api_pass(name_get_params.merge(updated_at: "20091012"))
    assert_api_results(goods)
  end

  def test_getting_names_with_without_synonyms
    without = Name.without_synonyms
    with    = Name.with_correct_spelling.with_synonyms
    assert_not_empty(without)
    assert_not_empty(with)
    assert_api_pass(name_get_params.merge(has_synonyms: "no"))
    assert_api_results(without)
    assert_api_pass(name_get_params.merge(has_synonyms: "true"))
    assert_api_results(with)
  end

  def test_getting_names_locations
    loc   = locations(:burbank)
    names = loc.observations.map(&:name).
            flatten.uniq.sort_by(&:id).
            reject(&:correct_spelling_id)
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(location: loc.id))
    assert_api_results(names)
  end

  def test_getting_names_species_lists
    spl   = species_lists(:unknown_species_list)
    names = spl.observations.map(&:name).
            flatten.uniq.sort_by(&:id).
            reject(&:correct_spelling_id)
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(species_list: spl.id))
    assert_api_results(names)
  end

  def test_getting_names_with_rank
    names = Name.with_correct_spelling.with_rank("Variety")
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(rank: "variety"))
    assert_api_results(names)
  end

  def test_getting_names_with_author
    with    = Name.with_correct_spelling.with_author
    without = Name.with_correct_spelling.without_author
    assert_not_empty(with)
    assert_not_empty(without)
    assert_api_pass(name_get_params.merge(has_author: "yes"))
    assert_api_results(with)
    assert_api_pass(name_get_params.merge(has_author: "no"))
    assert_api_results(without)
  end

  def test_getting_names_with_citation
    with    = Name.with_correct_spelling.with_citation
    without = Name.with_correct_spelling.without_citation
    assert_not_empty(with)
    assert_not_empty(without)
    assert_api_pass(name_get_params.merge(has_citation: "yes"))
    assert_api_results(with)
    assert_api_pass(name_get_params.merge(has_citation: "no"))
    assert_api_results(without)
  end

  def test_getting_names_with_classification
    with    = Name.with_correct_spelling.with_classification
    without = Name.with_correct_spelling.without_classification
    assert_not_empty(with)
    assert_not_empty(without)
    assert_api_pass(name_get_params.merge(has_classification: "yes"))
    assert_api_results(with)
    assert_api_pass(name_get_params.merge(has_classification: "no"))
    assert_api_results(without)
  end

  def test_getting_names_with_notes
    with    = Name.with_correct_spelling.with_notes
    without = Name.with_correct_spelling.without_notes
    assert_not_empty(with)
    assert_not_empty(without)
    assert_api_pass(name_get_params.merge(has_notes: "yes"))
    assert_api_results(with)
    assert_api_pass(name_get_params.merge(has_notes: "no"))
    assert_api_results(without)
  end

  def test_getting_names_with_comment
    names = Comment.where(target_type: "Name").map(&:target).
            uniq.sort_by(&:id).reject(&:correct_spelling_id)
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(has_comments: "yes"))
    assert_api_results(names)
  end

  def test_getting_names_with_description
    with    = Name.with_correct_spelling.with_description
    without = Name.with_correct_spelling.without_description
    assert_not_empty(with)
    assert_not_empty(without)
    assert_api_pass(name_get_params.merge(has_description: "yes"))
    assert_api_results(with)
    assert_api_pass(name_get_params.merge(has_description: "no"))
    assert_api_results(without)
  end

  def test_getting_names_text_name_contains
    names = Name.with_correct_spelling.text_name_contains("bunny")
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(text_name_has: "bunny"))
    assert_api_results(names)
  end

  def test_getting_names_author_contains
    names = Name.with_correct_spelling.author_contains("peck")
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(author_has: "peck"))
    assert_api_results(names)
  end

  def test_getting_names_citation_contains
    names = Name.with_correct_spelling.citation_contains("lichenes")
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(citation_has: "lichenes"))
    assert_api_results(names)
  end

  def test_getting_names_classification_contains
    names = Name.with_correct_spelling.classification_contains("lecanorales")
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(classification_has: "lecanorales"))
    assert_api_results(names)
  end

  def test_getting_names_notes_contain
    names = Name.with_correct_spelling.notes_contain("known")
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(notes_has: "known"))
    assert_api_results(names)
  end

  def test_getting_names_comment_contains
    names = Comment.where(
      Comment[:target_type].eq("name").and(Comment[:comment].matches("%mess%"))
    ).map(&:target).uniq.sort_by(&:id).reject(&:correct_spelling_id)
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(comments_has: "mess"))
    assert_api_results(names)
  end

  def test_getting_names_ok_for_export
    Name.with_correct_spelling.sample.update!(ok_for_export: true)
    names = Name.with_correct_spelling.ok_for_export
    assert_not_empty(names)
    assert_api_pass(name_get_params.merge(ok_for_export: "yes"))
    assert_api_results(names)
  end

  def test_creating_names
    @name           = "Parmeliaceae"
    @author         = ""
    @rank           = "Family"
    @deprecated     = true
    @citation       = ""
    @classification = ""
    @notes          = ""
    @user           = rolf
    params = {
      method: :post,
      action: :name,
      api_key: @api_key.key,
      name: @name,
      rank: @rank,
      deprecated: @deprecated
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:name))
    assert_api_fail(params.except(:rank))
    assert_api_fail(params.merge(name: "Agaricus"))
    assert_api_fail(params.merge(rank: "Species"))
    assert_api_fail(params.merge(classification: "spam spam spam"))
    assert_api_pass(params)
    assert_last_name_correct

    @name           = "Anzia ornata"
    @author         = "(Zahlbr.) Asahina"
    @rank           = "Species"
    @deprecated     = false
    @citation       = "Jap. Bot. 13: 219-226"
    @classification = "Kingdom: _Fungi_\r\nFamily: _Parmeliaceae_"
    @notes          = "neat species!"
    @user           = rolf
    params = {
      method: :post,
      action: :name,
      api_key: @api_key.key,
      name: @name,
      author: @author,
      rank: @rank,
      deprecated: @deprecated,
      citation: @citation,
      classification: @classification,
      notes: @notes
    }
    assert_api_pass(params)
    assert_last_name_correct(Name.where(text_name: @name).first)
    assert_not_empty(Name.where(text_name: "Anzia"))
  end

  def test_patching_name_attributes
    agaricus = names(:agaricus)
    lepiota  = names(:lepiota)
    new_classification = [
      "Kingdom: Fungi",
      "Class: Basidiomycetes",
      "Order: Agaricales",
      "Family: Agaricaceae"
    ].join("\n")
    params = {
      method: :patch,
      action: :name,
      api_key: @api_key.key,
      id: agaricus.id,
      set_notes: "new notes",
      set_citation: "new citation",
      set_classification: new_classification
    }

    lepiota.update!(user: mary)

    # Just to be clear about the starting point, the only objects attached to
    # this name at first are a version and a description, both owned by rolf,
    # the same user who created the name.  So it should be modifiable as it is.
    # The plan is to temporarily attach one object at a time to make sure it is
    # *not* modifiable if anything is wrong.
    assert_objs_equal(rolf, agaricus.user)
    assert_not_empty(agaricus.versions.select { |v| v.user_id == rolf.id })
    assert_not_empty(agaricus.descriptions.select { |v| v.user == rolf })
    assert_empty(agaricus.versions.reject { |v| v.user_id == rolf.id })
    assert_empty(agaricus.descriptions.reject { |v| v.user == rolf })
    assert_empty(agaricus.observations)
    assert_empty(agaricus.namings)

    # Not allowed to change if anyone else has an observation of that name.
    obs = observations(:minimal_unknown_obs)
    assert_objs_equal(mary, obs.user)
    obs.update!(name: agaricus)
    assert_api_fail(params)
    obs.update!(name: lepiota)

    # But allow it if rolf owns that observation.
    obs = observations(:coprinus_comatus_obs)
    assert_objs_equal(rolf, obs.user)
    obs.update!(name: agaricus)

    # Not allowed to change if anyone else has proposed that name.
    nam = namings(:detailed_unknown_naming)
    assert_objs_equal(mary, nam.user)
    nam.update!(name: agaricus)
    assert_api_fail(params)
    nam.update!(name: lepiota)

    # But allow it if rolf owns that name proposal.
    nam = namings(:coprinus_comatus_naming)
    assert_objs_equal(rolf, nam.user)
    nam.update!(name: agaricus)

    # Not allowed to change if user didn't create it.
    agaricus.update!(user: mary)
    assert_api_fail(params)
    agaricus.update!(user: rolf)

    # Okay, permissions should be right, now.  Proceed to "normal" tests.  That
    # is, make sure api key is required, and that classification is valid.
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.merge(set_classification: "spam spam spam"))
    assert_api_pass(params)

    agaricus.reload
    assert_equal("new notes", agaricus.notes)
    assert_equal("new citation", agaricus.citation)
    assert_equal(Name.validate_classification("Genus", new_classification),
                 agaricus.classification)
  end

  def test_changing_names
    agaricus = names(:agaricus)
    params = {
      method: :patch,
      action: :name,
      api_key: @api_key.key,
      id: agaricus.id
    }
    assert_api_fail(params.merge(set_name: ""))
    assert_api_pass(params.merge(set_name: "Suciraga"))
    assert_equal("Suciraga", agaricus.reload.text_name)
    assert_api_pass(params.merge(set_author: "L."))
    assert_equal("Suciraga L.", agaricus.reload.search_name)
    assert_api_pass(params.merge(set_rank: "order"))
    assert_equal("Order", agaricus.reload.rank)
    assert_api_fail(params.merge(set_rank: ""))
    assert_api_fail(params.merge(set_rank: "species"))
    assert_api_pass(params.merge(set_name: "Agaricus bitorquis",
                                 set_author: "(Quélet) Sacc.",
                                 set_rank: "species"))
    agaricus.reload
    assert_equal("Agaricus bitorquis (Quélet) Sacc.", agaricus.search_name)
    assert_equal("Species", agaricus.rank)
    parent = Name.where(text_name: "Agaricus").to_a
    assert_not_empty(parent)
    assert_not_equal(agaricus.id, parent[0].id)
  end

  def test_changing_deprecation
    agaricus = names(:agaricus)
    params = {
      method: :patch,
      action: :name,
      api_key: @api_key.key,
      id: agaricus.id
    }
    assert_api_pass(params.merge(set_deprecated: "true"))
    assert_true(agaricus.reload.deprecated)
    assert_equal("__Agaricus__", agaricus.display_name)
    assert_api_pass(params.merge(set_deprecated: "false"))
    assert_false(agaricus.reload.deprecated)
    assert_equal("**__Agaricus__**", agaricus.display_name)
  end

  def test_changing_synonymy
    name1 = names(:lactarius_alpigenes)
    name2 = names(:lactarius_subalpinus)
    name3 = names(:macrolepiota_rhacodes)
    params = {
      method: :patch,
      action: :name,
      api_key: @api_key.key
    }
    syns = name1.synonyms
    assert(syns.count > 2)
    assert(syns.include?(name2))
    assert_api_pass(params.merge(id: name1.id, clear_synonyms: "yes"))
    assert_obj_arrays_equal([name1], Name.find(name1.id).synonyms)
    assert_obj_arrays_equal((syns - [name1]).sort_by(&:id),
                            Name.find(name2.id).synonyms.sort_by(&:id))
    assert_api_fail(params.merge(id: name2.id, synonymize_with: name1.id))
    assert_api_pass(params.merge(id: name1.id, synonymize_with: name2.id))
    assert_obj_arrays_equal(syns, Name.find(name1.id).synonyms)
    assert_api_fail(params.merge(id: name1.id, synonymize_with: name3.id))
  end

  def test_changing_correct_spelling
    correct  = names(:macrolepiota_rhacodes)
    misspelt = names(:macrolepiota_rachodes)
    params = {
      method: :patch,
      action: :name,
      api_key: @api_key.key
    }
    correct.clear_synonym
    assert_api_pass(params.merge(id: misspelt.id,
                                 set_correct_spelling: correct.id))
    misspelt = Name.find(misspelt.id) # reload might not be enough
    assert_true(misspelt.deprecated)
    assert_names_equal(correct, misspelt.correct_spelling)
    assert_obj_arrays_equal([correct, misspelt].sort_by(&:id),
                            misspelt.synonyms.sort_by(&:id))
  end

  def test_deleting_names
    name = rolf.names.sample
    params = {
      method: :delete,
      action: :name,
      api_key: @api_key.key,
      id: name.id
    }
    # No DELETE requests should be allowed at all.
    assert_api_fail(params)
  end
end
