# frozen_string_literal: true

require("test_helper")

# Tests for Name::Format (app/models/name/format.rb)
class Name::FormatTest < UnitTestCase
  def test_hiding_authors
    dick.hide_authors = "above_species"
    mary.hide_authors = "none"

    name = names(:agaricus_campestris)
    assert_equal("**__Agaricus__** **__campestris__** L.",
                 name.display_name(mary))
    assert_equal("**__Agaricus__** **__campestris__** L.",
                 name.display_name(dick))

    name = names(:macrocybe_titans)
    assert_equal("**__Macrocybe__** Titans", name.display_name(mary))
    assert_equal("**__Macrocybe__**", name.display_name(dick))

    name.display_name = "__Macrocybe__ (Author) Author"
    assert_equal("__Macrocybe__", name.display_name(dick))

    name.display_name = "__Macrocybe__ (van Helsing) Author"
    assert_equal("__Macrocybe__", name.display_name(dick))

    name.display_name = "__Macrocybe__ sect. __Helsing__ Author"
    assert_equal("__Macrocybe__ sect. __Helsing__",
                 name.display_name(dick))

    name.display_name = "__Macrocybe__ sect. __Helsing__"
    assert_equal("__Macrocybe__ sect. __Helsing__",
                 name.display_name(dick))

    name.display_name = "**__Macrocybe__** (van Helsing) Author"
    assert_equal("**__Macrocybe__**", name.display_name(dick))

    name.display_name = "**__Macrocybe__** sect. **__Helsing__** Author"
    assert_equal("**__Macrocybe__** sect. **__Helsing__**",
                 name.display_name(dick))

    name.display_name = "**__Macrocybe__** sect. **__Helsing__**"
    assert_equal("**__Macrocybe__** sect. **__Helsing__**",
                 name.display_name(dick))

    name.display_name = "**__Macrocybe__** subgenus **__Blah__**"
    assert_equal("**__Macrocybe__** subgenus **__Blah__**",
                 name.display_name(dick))
  end

  def test_display_name_brief_authors
    # Name 0 authors
    assert_equal(names(:russula_brevipes_no_author).display_name,
                 names(:russula_brevipes_no_author).display_name_brief_authors)

    # Name 1 author
    assert_equal(
      names(:russula_brevipes_author_notes).display_name,
      names(:russula_brevipes_author_notes).display_name_brief_authors
    )

    # Name 2 authors
    assert_equal(
      names(:hygrocybe_russocoriacea_good_author).display_name,
      names(:hygrocybe_russocoriacea_good_author).display_name_brief_authors
    )

    # Name > 2 authors
    assert_equal("**__Coprinellus__** **__micaceus__** (Bull.) Vilgalys et al.",
                 names(:coprinellus_micaceus).display_name_brief_authors)

    # Name > 2 authors in parentheses
    authors = "(Author1, Author2 & Author3) Author4, Author5 & Author6"
    name = Name.new(
      text_name: "Xxx #{authors}",
      display_name: "**__Xxx__** #{authors}",
      author: authors.to_s,
      rank: "Genus",
      deprecated: false, correct_spelling: nil,
      user: users(:rolf)
    )
    assert_equal("**__Xxx__** (Author1 et al.) Author4 et al.",
                 name.display_name_brief_authors)

    # Autonym <= 2 authors
    autonym = Name.new(
      text_name: "Russula sect. Russula",
      display_name: "**__Russula__** Pers. sect. **__Russula__**",
      author: "Pers.",
      rank: "Section",
      deprecated: false, correct_spelling: nil,
      user: users(:rolf)
    )
    assert_equal(autonym.display_name,
                 autonym.display_name_brief_authors)

    # Autonym > 2 authors
    authors = "Redhead, Vizzini, Drehmel & Contu"
    autonym = Name.new(
      text_name: "Saproamanita sect. Saproamanita",
      display_name: "**__Saproamanita__** #{authors} sect. Saproamanita",
      author: authors,
      rank: "Section",
      deprecated: false, correct_spelling: nil,
      user: users(:rolf)
    )
    assert_equal("**__Saproamanita__** Redhead et al. sect. Saproamanita",
                 autonym.display_name_brief_authors)

    # group <= 2 authors
    assert_equal(names(:authored_group).display_name,
                 names(:authored_group).display_name_brief_authors)

    # group > 2 authors
    authors = "Author1, Author2 & Author3"
    group_name = Name.new(
      text_name: "Xxx yyy clade #{authors}",
      display_name: "**__Xxx__** **__yyy__** clade #{authors}",
      author: authors,
      rank: "Group",
      deprecated: false, correct_spelling: nil,
      user: users(:rolf)
    )
    assert_equal("**__Xxx__** **__yyy__** clade Author1 et al.",
                 group_name.display_name_brief_authors)
  end

  def test_display_name_without_authors
    # Name with 0 authors
    assert_equal(
      names(:russula_brevipes_no_author).display_name,
      names(:russula_brevipes_no_author).display_name_without_authors
    )

    # Name with author
    assert_equal(
      "**__Russula__** **__brevipes__**",
      names(:russula_brevipes_author_notes).display_name_without_authors
    )

    # Autonym with author
    autonym = Name.create!(
      text_name: "Russula sect. Russula",
      author: "Pers.",
      search_name: "Russula Pers. sect. Russula",
      display_name: "**__Russula__** Pers. sect. **__Russula__**",
      rank: "Section",
      deprecated: false, correct_spelling: nil,
      user: users(:rolf)
    )
    assert_equal("**__Russula__** sect. **__Russula__**",
                 autonym.display_name_without_authors)

    # group without author
    assert_equal(names(:unauthored_group).display_name,
                 names(:unauthored_group).display_name_without_authors)

    # group with author
    assert_equal("**__Groupauthored__** group",
                 names(:authored_group).display_name_without_authors)

    # Autonym
    assert_equal("**__Agaricus__** sect. **__Agaricus__**",
                 names(:sect_agaricus).display_name_without_authors)
  end

  def test_display_name_without_authors_with_user
    # group with author - threads `user` through to `display_name`
    assert_equal(
      "**__Groupauthored__** group",
      names(:authored_group).display_name_without_authors(mary)
    )

    # non-group with author
    assert_equal(
      "**__Russula__** **__brevipes__**",
      names(:russula_brevipes_author_notes).
        display_name_without_authors(mary)
    )
  end

  def test_unknown_and_known
    assert(Name.unknown.unknown?)
    assert_not(Name.unknown.known?)

    assert_not(names(:coprinus_comatus).unknown?)
    assert(names(:coprinus_comatus).known?)
  end

  def test_make_sure_names_are_bolded_correctly
    name = names(:suilus)
    assert_equal("**__#{name.text_name}__** #{name.author}", name.display_name)
    Name.make_sure_names_are_bolded_correctly
    name.reload
    assert_equal("__#{name.text_name}__ #{name.author}", name.display_name)
  end

  def test_sensu_stricto
    %w[group gr gr. gp gp. clade complex].each do |str|
      assert_equal("Boletus",
                   Name.new(text_name: "Boletus #{str}").sensu_stricto,
                   "Name s.s. should not include `#{str}`")
      assert_equal(Name.new(text_name: "Boletus#{str}").sensu_stricto,
                   "Boletus#{str}",
                   "Name ss should include `#{str}` if it's part of the genus")
    end

    # start of the epithet matches a `group` abbreviation ("gr")
    name = Name.new(text_name: "Leptonia gracilipes")

    assert_equal(name.text_name, name.sensu_stricto)
  end

  def test_imageless
    assert_true(names(:imageless).imageless?)
    assert_false(names(:fungi).imageless?)
  end

  def test_more_brief_authors
    name = Name.new

    name.author = "(A, B, C, D & E)"
    assert_equal("(A et al.)", name.send(:brief_author))

    name.author = "(Blah) A, B, C, D & E"
    assert_equal("(Blah) A et al.", name.send(:brief_author))

    name.author = "One & Two, nom. prov."
    assert_equal("One & Two, nom. prov.", name.send(:brief_author))

    name.author = "(A, B & C) D, E & F ined."
    assert_equal("(A et al.) D et al. ined.", name.send(:brief_author))

    name.author = "(A, B & C) D, E & F nom illeg"
    assert_equal("(A et al.) D et al. nom illeg", name.send(:brief_author))

    name.author = "(A, B & C) D, E & F nom cons"
    assert_equal("(A et al.) D et al.", name.send(:brief_author))

    name.author = "(A, B & C) D, E & F, sp. nov."
    assert_equal("(A et al.) D et al.", name.send(:brief_author))
  end
end
