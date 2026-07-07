# frozen_string_literal: true

require("test_helper")

# Split by Name model module - see test/models/name/*.rb for the rest.
# require_relative'd (not left to directory-wide test discovery) so
# `bin/rails test test/models/name_test.rb` on its own still runs them.
require_relative("name/parse_test")
require_relative("name/taxonomy_test")
require_relative("name/validation_test")
require_relative("name/format_test")
require_relative("name/synonymy_test")
require_relative("name/notify_test")
require_relative("name/spelling_test")
require_relative("name/change_test")

# Tests for methods in models/name.rb and models/name/xxx.rb
class NameTest < UnitTestCase
  include ActiveJob::TestHelper

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

  ##############################################################################

  # ----------------------------------------------
  #  Test find_or_create_name_and_parents (Name::Create).
  # ----------------------------------------------

  def test_find_or_create_name_and_parents
    # Coprinus comatus already has an author.
    # Create new subspecies Coprinus comatus v. bogus and make sure it doesn't
    # create a duplicate species if one already exists.
    # Saw this bug 20080114 -JPH
    result = Name.find_or_create_name_and_parents(
      rolf, "Coprinus comatus v. bogus (With) Author"
    )
    assert_equal(3, result.length)
    assert_equal(names(:coprinus).id, result[0].id)
    assert_equal(names(:coprinus_comatus).id, result[1].id)
    assert_nil(result[2].id)
    assert_equal("Coprinus", result[0].text_name)
    assert_equal("Coprinus comatus", result[1].text_name)
    assert_equal("Coprinus comatus var. bogus", result[2].text_name)
    assert_equal(names(:coprinus).author, result[0].author)
    assert_equal("(O.F. Müll.) Pers.", result[1].author)
    assert_equal("(With) Author", result[2].author)

    # Conocybe filaris does not have an author.
    result = Name.find_or_create_name_and_parents(
      rolf, "Conocybe filaris var bogus (With) Author"
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
    result = Name.find_or_create_name_and_parents(rolf, "Agaricus L.")
    assert_equal(1, result.length)
    assert_equal(names(:agaricus).id, result[0].id)
    assert_equal("Agaricus", result[0].text_name)
    assert_equal("L.", result[0].author)

    # Agaricus does not have an author.
    result = Name.find_or_create_name_and_parents(
      rolf, "Agaricus abra f. cadabra (With) Another Author"
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

  # --------------------------------------
  #  Test email notification heuristics.
  # --------------------------------------

  def test_lichen
    assert(names(:tremella_mesenterica).is_lichen?)
    assert(names(:tremella).is_lichen?)
    assert(names(:tremella_justpublished).is_lichen?)
    assert_not(names(:agaricus_campestris).is_lichen?)
  end

  # Verify mysql collates accented authors in the expected Unicode order.
  # Only meaningful when the DB has an accent-sensitive collation; passes
  # trivially otherwise.
  def test_mysql_sort_order
    if sql_collates_accents?
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
    else
      pass
    end
  end

  # Prove that Name spaceship operator (<=>) uses sort_name to sort Names
  def test_name_spaceship_operator
    # names ordered by how spaceship operator is expected to sort them
    names = [
      create_test_name("Agaricomycota"), # phylum
      create_test_name("Agaricomycotina"), # subphylum
      create_test_name("Agaricomycetes"), # class
      create_test_name("Agaricomycetidae"), # subclass
      create_test_name("Agaricales"), # order
      create_test_name("Agaricineae"), # suborder
      create_test_name("Agaricaceae"), # family
      create_test_name("Agaricus group"), # genus group
      create_test_name("Agaricus Aaron"), # genus author
      create_test_name("Agaricus L."), # genus
      create_test_name("Agaricus Øosting"),
      create_test_name("Agaricus Zzyzx"),
      create_test_name("Agaricus Đorn"),
      create_test_name("Agaricus subgenus Dick"),
      create_test_name("Agaricus section Charlie"),
      create_test_name("Agaricus subsection Bob"),
      create_test_name("Agaricus ser. Alpha"),
      create_test_name("Agaricus stirps Arthur"),
      # spaceship operator sorts Ś after {. Therefore
      # "Agaricus  {4stirps  Arthur" sorts before
      # "Agaricus  Śliwa" which sorts before Species and lower
      # whose sort_name's have only one space.
      create_test_name("Agaricus Śliwa"),
      create_test_name("Agaricus aardvark"),
      create_test_name("Agaricus aardvark group"),
      create_test_name('Agaricus "sp-LD50"'),
      create_test_name('Agaricus "tree-beard"'),
      create_test_name("Agaricus ugliano Zoom"),
      create_test_name("Agaricus ugliano ssp. ugliano Zoom"),
      create_test_name("Agaricus ugliano ssp. erik Zoom"),
      create_test_name("Agaricus ugliano var. danny Zoom"),
      # Xyl- names share the stem "Xyl" to verify
      # Family→Subfamily→Tribe→Subtribe order
      create_test_name("Xylaceae"),   # family:    Xyl!7
      create_test_name("Xyloideae"),  # subfamily: Xyl!8
      create_test_name("Xyleae"),     # tribe:     Xyl!8a
      create_test_name("Xylinae")     # subtribe:  Xyl!9
    ]
    sort_names = names.map(&:sort_name)
    assert_equal(sort_names, sort_names.sort,
                 "Names should sort in rank order within same stem")
  end

  # Prove that alphabetized sort_names give us names in the expected order
  # Differs from test_name_spaceship_operator in omitting "Agaricus Śliwa",
  # whose sort_name is after all the levels between genus and species,
  # apparently because "Ś" sorts after "{".
  def test_name_sort_order
    names = [
      create_test_name("Agaricomycota"), # phylum
      create_test_name("Agaricomycotina"), # subphylum
      create_test_name("Agaricomycetes"), # class
      create_test_name("Agaricomycetidae"), # subclass
      create_test_name("Agaricales"), # order
      create_test_name("Agaricineae"), # suborder
      create_test_name("Agaricaceae"), # family
      create_test_name("Agaricus group"), # genugroup
      create_test_name("Agaricus Aaron"), # genu
      create_test_name("Agaricus L."),
      create_test_name("Agaricus Øosting"),
      create_test_name("Agaricus Zzyzx"),
      create_test_name("Agaricus Đorn"),
      create_test_name("Agaricus subgenus Dick"),
      create_test_name("Agaricus section Charlie"),
      create_test_name("Agaricus subsection Bob"),
      create_test_name("Agaricus ser. Alpha"),
      create_test_name("Agaricus stirps Arthur"),
      create_test_name("Agaricus aardvark"), # species
      create_test_name("Agaricus aardvark group"), # (species) group
      create_test_name('Agaricus "sp-LD50"'),
      create_test_name('Agaricus "tree-beard"'),
      create_test_name("Agaricus ugliano Zoom"),
      create_test_name("Agaricus ugliano ssp. ugliano Zoom"),
      create_test_name("Agaricus ugliano ssp. erik Zoom"),
      create_test_name("Agaricus ugliano var. danny Zoom")
    ]
    expected_sort_names = names.map(&:sort_name)
    sorted_sort_names = names.sort.map(&:sort_name)

    assert_equal(expected_sort_names, sorted_sort_names)
  end

  def test_names_matching_desired_new_parsed_name
    # Prove unauthored ParseName matches are all extant matches to text_name
    # Such as multiple authored Names
    parsed = Name.parse_name("Amanita baccata")
    expect = [names(:amanita_baccata_arora), names(:amanita_baccata_borealis)]
    assert_equal(expect,
                 Name.matching_desired_new_parsed_name(parsed).order(:author))
    # or unauthored and authored Names
    parsed = Name.parse_name(names(:unauthored_with_naming).text_name)
    expect = [names(:unauthored_with_naming), names(:authored_with_naming)]
    assert_equal(expect,
                 Name.matching_desired_new_parsed_name(parsed).order(:author))

    # Prove authored Group ParsedName is not matched by extant unauthored Name
    parsed = Name.parse_name("#{names(:unauthored_group).text_name} Author")
    assert_not(Name.matching_desired_new_parsed_name(parsed).
                include?(names(:unauthored_with_naming)))
    # And vice versa
    # Prove unauthored Group ParsedName is not matched by extant authored Name
    extant = names(:authored_group)
    desired = extant.text_name
    parsed = Name.parse_name(desired)
    assert_not(Name.matching_desired_new_parsed_name(parsed).include?(extant),
               "'#{desired}' unexpectedly matches '#{extant.search_name}'")

    # Prove authored non-Group ParsedName matched by union of exact matches and
    # unauthored matches
    parsed = Name.parse_name(names(:authored_with_naming).search_name)
    expect = [names(:unauthored_with_naming), names(:authored_with_naming)]
    assert_equal(expect,
                 Name.matching_desired_new_parsed_name(parsed).order(:author))
  end

  def test_merge_editors
    old_name = names(:peltigera)
    editors = old_name.versions.each_with_object([]) do |version, e|
      e << version.user_id
    end.uniq
    assert(editors.many?,
           "Test needs Name fixture edited by multiple users")
    user = User.find(old_name.versions.second.user_id)
    old_contribution = user.contribution

    names(:lichen).merge(nil, old_name)

    assert_equal(
      old_contribution - UserStats::ALL_FIELDS[:name_versions][:weight],
      user.reload.contribution,
      "Merging a Name edited by a user should reduce user's contribution " \
      "by #{UserStats::ALL_FIELDS[:name_versions][:weight]}"
    )
  end

  def test_merge_interests
    old_name = names(:agaricus_campestros)
    interests = old_name.interests
    assert(interests.any?, "Test needs a fixture with an interest")
    target = names(:agaricus_campestras)
    assert(target.interests.none?, "Test needs a fixture without interests")

    target.merge(nil, old_name)
    assert_equal(
      interests, target.interests,
      "Old name (#{old_name.text_name}) interests " \
      "were not moved to target (#{target.text_name})"
    )
  end

  def test_can_propagate
    assert(names(:coprinus).can_propagate?,
           "Genus s.s. Classifications should be propagable")

    assert_false(names(:coprinus_sensu_lato).can_propagate?,
                 "Names sensu lato Classifications should not be propagable")

    [:eukarya, :fungi, :ascomycota, :ascomycetes, :agaricales, :agaricaceae,
     :amanita_subgenus_lepidella, :sect_agaricus, :coprinus_comatus,
     :amanita_boudieri_var_beillei, :boletus_edulis_group].
      each do |name|
        assert_false(
          names(name).can_propagate?,
          "#{names(name).rank} Classifications should not be propagable"
        )
      end
  end

  def test_propagate_generic_classifications
    # This should result in the classification of Coprinus being copied to
    # Chlorophyllum rachodes.
    c_rachodes = names(:chlorophyllum_rachodes)
    c_comatus = names(:coprinus_comatus)
    c_rachodes.merge_synonyms(c_comatus)
    c_rachodes.update(deprecated: true)
    c_comatus.update(deprecated: false)
    wrong_class = c_rachodes.classification.sub("Agaricaceae", "Boletaceae")
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
        msgs.exclude?("Filling in classification for Lepiota rachodes") &&
        msgs.exclude?("Stripping classification from Agaricus campestras"),
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

  def test_destroy_orphans_log
    loc = locations(:mitrula_marsh)
    log = loc.rss_log
    assert_not_nil(log)
    loc.destroy!
    assert_nil(log.reload.target_id)
  end

  def test_merge_orphans_log
    name1 = names(:coprinus)
    name2 = names(:fungi)
    log1 = name1.rss_log
    log2 = name2.rss_log
    assert_not_nil(log1)
    assert_not_nil(log2)
    name2.merge(nil, name1)
    assert_nil(log1.reload.target_id)
    assert_not_nil(log2.reload.target_id)
    assert_equal(:log_orphan, log1.parse_log[0][0])
    assert_equal(:log_name_merged, log1.parse_log[1][0])
  end

  # `merge` wraps every step in a transaction - a failure partway
  # through must roll back everything already moved, not leave the DB
  # half-merged with old_name still around but stripped of its data.
  def test_merge_rolls_back_all_changes_if_a_step_raises
    old_name = names(:conocybe_filaris)
    survivor = names(:coprinus_comatus)
    old_obs_ids = old_name.observations.map(&:id)
    assert(old_obs_ids.any?, "Test needs old_name to have observations")

    survivor.stub(:move_versions, ->(*) { raise("boom") }) do
      assert_raises(RuntimeError) { survivor.merge(rolf, old_name) }
    end

    assert(Name.exists?(old_name.id),
           "old_name should still exist - merge should have rolled back")
    assert_equal(old_obs_ids.sort, old_name.reload.observations.map(&:id).sort,
                 "old_name's observations should not have been moved")
  end

  # `move_mispellings` runs once early (the normal snapshot) and once
  # again immediately before `old_name.destroy` (the re-snapshot).
  # A misspelling pointed at old_name in the gap between those two
  # calls - simulating a concurrent request - must still be caught by
  # the re-snapshot rather than left with a dangling correct_spelling_id
  # once old_name is destroyed.
  def test_merge_reassigns_misspelling_created_during_merge
    old_name = names(:conocybe_filaris)
    survivor = names(:coprinus_comatus)
    racer = nil

    original_move_followings = survivor.method(:move_followings)
    survivor.stub(:move_followings, lambda { |old|
      racer = Name.create!(text_name: "Raceria", search_name: "Raceria",
                           sort_name: "Raceria", display_name: "__Raceria__",
                           rank: Name.ranks[:Genus], user: rolf)
      racer.update_column(:correct_spelling_id, old.id)
      original_move_followings.call(old)
    }) do
      survivor.merge(rolf, old_name)
    end

    assert_equal(survivor.id, racer.reload.correct_spelling_id,
                 "Misspelling created mid-merge should be caught by the " \
                 "re-snapshot before destroy, not left dangling")
  end

  # ----------------------------------------------------
  #  Scopes
  #    Explicit tests of some scopes to improve coverage
  # ----------------------------------------------------

  def test_scope_subtaxa_of
    mispelled_name = Name.create!(
      text_name: "Amanita boodairy",
      author: "",
      search_name: "Amanita boodairy",
      display_name: "__Amanita__ __boodairy__ ",
      correct_spelling: names(:amanita_boudieri),
      deprecated: true,
      rank: "Species",
      user: users(:rolf)
    )

    amanita = names(:amanita)
    subtaxa_of_amanita = Name.subtaxa_of(amanita).order_by_default
    immediate_subtaxa_of_amanita = Name.immediate_subtaxa_of(amanita).
                                   order_by_default
    include_immediate_subtaxa = Name.include_immediate_subtaxa_of(amanita).
                                order_by_default

    # Immediate subtaxa of a genus should include everything below the genus.
    assert_equal(subtaxa_of_amanita.map(&:id),
                 immediate_subtaxa_of_amanita.map(&:id))
    assert_equal([amanita.id] + subtaxa_of_amanita.map(&:id),
                 include_immediate_subtaxa.map(&:id))

    assert_includes(
      subtaxa_of_amanita, names(:amanita_subgenus_lepidella),
      "`subtaxa_of` a genus should include subgenera"
    )
    assert_includes(
      subtaxa_of_amanita, names(:amanita_subgenus_lepidella),
      "`subtaxa_of` a genus should include subgenera"
    )
    assert_includes(
      subtaxa_of_amanita, names(:amanita_boudieri),
      "`subtaxa_of` a genus should include species"
    )
    assert_includes(
      subtaxa_of_amanita, names(:amanita_boudieri_var_beillei),
      "`subtaxa_of` a genus should include variety"
    )
    assert_includes(
      Name.subtaxa_of(names(:amanita_boudieri)),
      names(:amanita_boudieri_var_beillei),
      "`subtaxa_of` a species should include variety"
    )
    assert_includes(
      Name.subtaxa_of(names(:pluteus)),
      names(:pluteus_petasatus_deprecated),
      "`subtaxa_of` should include deprecated, but correctly spelled, names"
    )
    assert_includes(
      Name.subtaxa_of(names(:boletus)),
      names(:boletus_edulis_group),
      "`subtaxa_of` a genus should include species groups"
    )
    assert_includes(
      Name.subtaxa_of(names(:agaricales)),
      names(:agaricaceae),
      "`subtaxa_of` a class should include family whose classification" \
      "includes that class"
    )
    # This is a counter-intuitive compromise for an edge case.
    # See comments in test_scope_subtaxa_of_genus_or_below
    assert_includes(
      Name.subtaxa_of(names(:boletus_edulis)),
      names(:boletus_edulis_group),
      "`subtaxa_of` <name> should include <name> group"
    )

    # -----------------

    assert_not_includes(
      subtaxa_of_amanita, names(:amanita),
      "`subtaxa_of` a genus should not include that genus"
    )
    assert_not_includes(
      subtaxa_of_amanita, names(:boletus_edulis),
      "`subtaxa_of` a genus should not species from other genera"
    )
    assert_not_includes(
      subtaxa_of_amanita, mispelled_name,
      "`subtaxa_of` should not include misspellings"
    )

    # Above-genus: immediate_subtaxa_of returns the next rank down, not all
    # descendants. One assertion per new intermediate rank.
    assert_includes(
      Name.immediate_subtaxa_of(names(:basidiomycota)),
      names(:agaricomycotina),
      "`immediate_subtaxa_of` a Phylum should return Subphylum subtaxa"
    )
    assert_includes(
      Name.immediate_subtaxa_of(names(:basidiomycetes)),
      names(:agaricomycetidae),
      "`immediate_subtaxa_of` a Class should return Subclass subtaxa"
    )
    immediate_subtaxa_of_agaricales =
      Name.immediate_subtaxa_of(names(:agaricales))
    assert_includes(
      immediate_subtaxa_of_agaricales, names(:agaricineae),
      "`immediate_subtaxa_of` an Order should return Suborder subtaxa"
    )
    assert_not_includes(
      immediate_subtaxa_of_agaricales, names(:amanita),
      "`immediate_subtaxa_of` an Order should not include Genus-ranked names"
    )
    assert_includes(
      Name.immediate_subtaxa_of(names(:agaricaceae)),
      names(:agaricioideae),
      "`immediate_subtaxa_of` a Family should return Subfamily subtaxa"
    )
    assert_includes(
      Name.immediate_subtaxa_of(names(:agaricioideae)),
      names(:agariceae),
      "`immediate_subtaxa_of` a Subfamily should return Tribe subtaxa"
    )
    assert_includes(
      Name.immediate_subtaxa_of(names(:agariceae)),
      names(:agaricinae),
      "`immediate_subtaxa_of` a Tribe should return Subtribe subtaxa"
    )
  end

  def test_scope_names_for_subtaxa_of_genus_or_below
    amanita_group = Name.create!(
      text_name: "Amanita group",
      search_name: "Amanita group",
      display_name: "__Amanita__ group",
      correct_spelling: nil,
      deprecated: false,
      rank: "Group",
      user: users(:rolf)
    )
    amanita_sensu_lato = Name.create!(
      text_name: "Amanita",
      author: "sensu lato",
      search_name: "Amanita sensu lato",
      display_name: "__Amanita__ sensu lato",
      correct_spelling: nil,
      deprecated: false,
      rank: "Genus",
      user: users(:rolf)
    )

    # Since lookup now does pattern matching when include_subtaxa is
    # true rather than precise name matching, "Amanita group" is now
    # included when you select "include_subtaxa".
    assert_includes(
      Name.names(lookup: "Amanita", include_subtaxa: true), amanita_group,
      "`include_subtaxa` at or below genus <X> should include `<X> group`"
    )
    # However, the semantics of exclude_original_names has now changed
    # to exclude the any of the pattern matching names.
    assert_not_includes(
      Name.names(
        lookup: "Amanita", include_subtaxa: true, exclude_original_names: true
      ), amanita_group,
      "`include_subtaxa` and `exclude_original_names` should not include " \
      "`<X> group`"
    )

    assert_not_includes(
      Name.names(
        lookup: "Amanita", include_subtaxa: true, exclude_original_names: true
      ), amanita_sensu_lato,
      "`include_subtaxa` at or below genus <X> should not include " \
      "`<X> sensu lato`"
    )
  end

  # Currently Query ignores false, so scope does too.
  # def test_scope_has_comments_false
  #   assert_includes(Name.has_comments(false), names(:bugs_bunny_one))
  #   assert_not_includes(Name.has_comments(false), names(:fungi))
  # end

  def test_scope_comments_has
    assert_includes(Name.comments_has("do not change"), names(:fungi))
    assert_empty(Name.comments_has(ARBITRARY_SHA))
    assert_empty(
      Name.comments_has(comments(:detailed_unknown_obs_comment).summary)
    )
  end

  def test_scope_classification_has_includes_genus
    # Classification column doesn't include Genus, but scientifically it should.
    # Searching for "Coprinus" should find species in that genus.
    coprinus = names(:coprinus)
    coprinus_comatus = names(:coprinus_comatus)

    results = Name.classification_has("Coprinus")

    assert_includes(results, coprinus,
                    "Should find genus itself")
    assert_includes(results, coprinus_comatus,
                    "Should find species within the genus")
  end

  def test_scope_classification_has_with_species_name
    # Searching for a binomial like "Amanita boudieri" should find the species
    # and its infraspecifics, but NOT other Amanita species.
    amanita_boudieri = names(:amanita_boudieri)
    amanita_boudieri_var = names(:amanita_boudieri_var_beillei)
    amanita_baccata = names(:amanita_baccata_arora)

    results = Name.classification_has("Amanita boudieri")

    assert_includes(results, amanita_boudieri,
                    "Should find Amanita boudieri")
    assert_includes(results, amanita_boudieri_var,
                    "Should find Amanita boudieri var. beillei")
    assert_not_includes(results, amanita_baccata,
                        "Should NOT find other Amanita species like baccata")
  end

  def test_scope_species_lists
    assert_includes(
      Name.species_lists(species_lists(:unknown_species_list)), names(:fungi)
    )
    assert_empty(Name.species_lists(species_lists(:first_species_list)))
  end

  def test_scope_within_locations
    # Have to do this, otherwise columns not populated
    Location.update_box_area_and_center_columns

    assert_includes(
      Name.within_locations(locations(:burbank)), # called with Location
      names(:agaricus_campestris)
    )
    assert_includes(
      Name.within_locations(locations(:burbank).id), # called with id
      names(:agaricus_campestris)
    )
    assert_includes(
      Name.within_locations(locations(:burbank).name), # called with string
      names(:agaricus_campestris)
    )
    assert_includes(
      Name.within_locations(locations(:california).name), # region
      names(:agaricus_campestris)
    )
    assert_not_includes(
      Name.within_locations(locations(:obs_default_location)),
      names(:notification_but_no_observation)
    )
    assert_empty(
      Name.within_locations({}),
      "Name.at_location should be empty if called with bad argument class"
    )
  end

  def test_scope_in_box
    cal = locations(:california)
    names_in_cal_box = Name.in_box(**cal.bounding_box)
    # Grab a couple of Names that are unused in Observation fixtures
    names_without_observations =
      Name.where.not(id: Name.joins(:observations)).distinct.limit(2).to_a
    obs_on_cal_border =
      Observation.create!(name: names_without_observations.first,
                          location: nil,
                          lat: cal.north,
                          lng: cal.east,
                          user: rolf)
    # Use a large location (box_area > threshold) so coordinates aren't cached
    obs_in_cal_without_lat_lng =
      Observation.create!(name: names_without_observations.second,
                          location: locations(:california),
                          lat: nil,
                          lng: nil,
                          user: rolf)

    assert_includes(names_in_cal_box, obs_on_cal_border.name)
    assert_not_includes(
      names_in_cal_box,
      obs_in_cal_without_lat_lng.name,
      "Name.in_box should exclude Names whose Observations have " \
      "large locations (box_area > threshold) with no GPS coordinates"
    )
    e = MO.box_epsilon
    box = { north: e, south: 0, east: e, west: 0 }
    assert_empty(Name.in_box(**box))
  end

  # Regression test for https://github.com/MushroomObserver/mushroom-observer/issues/4252
  # Versions must record who made each edit, not the name's original creator.
  def test_version_records_editor_not_creator
    name = names(:coprinus_comatus)
    assert_equal(rolf.id, name.user_id,
                 "Fixture name should be created by rolf")

    name.notes = "Updated by a different user"
    name.save_with_log(mary)

    last_version = name.versions.reload.last
    assert_equal(mary.id, last_version.user_id,
                 "Last version user_id should be the editor (mary), " \
                 "not the creator (rolf)")
  end

  # `show_includes` (used by NamesController#show/#edit/#update and
  # Names::VersionsController#show) deliberately omits `.namings`/
  # `.observations` — eager-loading either is expensive for a name
  # with many thousands of them (e.g. a genus), and none of those
  # actions reads them directly. `merge_includes` (used only by
  # `perform_merge_names`) still needs both. `strict_loading` means
  # a wrong scope fails loudly here rather than silently N+1-ing in
  # production.
  def test_show_includes_omits_namings_and_observations
    name = Name.show_includes.find(names(:coprinus_comatus).id)

    assert_raises(ActiveRecord::StrictLoadingViolationError) do
      name.namings.to_a
    end
    assert_raises(ActiveRecord::StrictLoadingViolationError) do
      name.observations.to_a
    end
  end

  def test_merge_includes_preloads_namings_and_observations
    name = Name.merge_includes.find(names(:coprinus_comatus).id)

    assert_nothing_raised { name.namings.to_a }
    assert_nothing_raised { name.observations.to_a }
  end
end
