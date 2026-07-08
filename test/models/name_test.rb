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
require_relative("name/merge_test")
require_relative("name/propagate_generic_classifications_test")
require_relative("name/scopes_test")
require_relative("name/create_test")
require_relative("name/lifeform_test")

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

  def test_destroy_orphans_log
    loc = locations(:mitrula_marsh)
    log = loc.rss_log
    assert_not_nil(log)
    loc.destroy!
    assert_nil(log.reload.target_id)
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
end
