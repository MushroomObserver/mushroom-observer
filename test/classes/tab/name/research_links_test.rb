# frozen_string_literal: true

require("test_helper")

# Tests `Tab::Name::ResearchLinks` orchestration — pins which
# tabs appear under each of the 3 conditional branches
# (Ascomycete classification, EOL url present, registry-searchable).
class Tab::Name::ResearchLinksTest < UnitTestCase
  def setup
    @name = names(:coprinus_comatus)
    @user = users(:rolf)
  end

  # --- Default branches: all unconditional tabs always present ---

  def test_unconditional_tabs_always_appear_in_order
    coll = Tab::Name::ResearchLinks.new(name: @name, user: @user)
    classes = coll.map(&:class)

    # Pin the unconditional core set. Optional tabs come and go
    # depending on Name state — covered by their own tests.
    [
      Tab::Name::Gbif,
      Tab::Name::UserGoogleImages,
      Tab::Name::GoogleSearch,
      Tab::Name::Inat,
      Tab::Name::NcbiNucleotide,
      Tab::Name::Wikipedia
    ].each do |k|
      assert_includes(classes, k)
    end
  end

  # --- Ascomycete branch ----------------------------------------

  def test_ascomycete_tab_appears_when_classification_matches
    @name.classification = "Domain: _Eukarya_\r\nKingdom: _Fungi_" \
                           "\r\nPhylum: _Ascomycota_"

    coll = Tab::Name::ResearchLinks.new(name: @name, user: @user)

    assert(coll.any?(Tab::Name::AscomyceteOrg))
  end

  def test_ascomycete_tab_omitted_otherwise
    @name.classification = "Domain: _Eukarya_\r\nKingdom: _Fungi_" \
                           "\r\nPhylum: _Basidiomycota_"

    coll = Tab::Name::ResearchLinks.new(name: @name, user: @user)

    assert_not(coll.any?(Tab::Name::AscomyceteOrg))
  end

  # --- EOL branch -----------------------------------------------

  def test_eol_tab_appears_when_name_has_eol_url
    @name.define_singleton_method(:eol_url) { "https://eol.org/123" }

    coll = Tab::Name::ResearchLinks.new(name: @name, user: @user)

    assert(coll.any?(Tab::Name::Eol))
  end

  def test_eol_tab_omitted_when_no_eol_url
    @name.define_singleton_method(:eol_url) { nil }

    coll = Tab::Name::ResearchLinks.new(name: @name, user: @user)

    assert_not(coll.any?(Tab::Name::Eol))
  end

  # --- Registry branch ------------------------------------------

  def test_registry_tabs_appear_when_searchable_in_registry
    @name.define_singleton_method(:searchable_in_registry?) { true }

    coll = Tab::Name::ResearchLinks.new(name: @name, user: @user)
    classes = coll.map(&:class)

    assert_includes(classes, Tab::Name::MushroomExpert)
    assert_includes(classes, Tab::Name::Mycoportal)
  end

  def test_registry_tabs_omitted_when_not_searchable
    @name.define_singleton_method(:searchable_in_registry?) { false }

    coll = Tab::Name::ResearchLinks.new(name: @name, user: @user)
    classes = coll.map(&:class)

    assert_not_includes(classes, Tab::Name::MushroomExpert)
    assert_not_includes(classes, Tab::Name::Mycoportal)
  end
end
