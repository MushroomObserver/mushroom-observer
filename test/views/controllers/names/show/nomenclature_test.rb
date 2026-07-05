# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Names::Show::NomenclatureTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  # When the name has an ICN id AND rank is Genus or Family,
  # `render_fungorum_synonymy_link` should emit the SF synonymy link
  # (Tab::Name::FungorumSfSynonymy) rather than the GSD link.
  def test_renders_sf_synonymy_link_for_genus_with_icn_id
    name = names(:coprinus) # rank: Genus
    name.icn_id = 17_253    # set an ICN id so icn_id? is true

    html = render_nomenclature(name: name)

    # The SF link points at speciesfungorum.org with the ICN id
    expected_url = "http://www.speciesfungorum.org/Names/SynSpecies.asp" \
                   "?RecordID=#{name.icn_id}"
    assert_html(html, "a[href='#{expected_url}']")
  end

  def test_at_or_below_species_renders_gsd_link_not_sf_link
    name = names(:coprinus_comatus) # rank: Species
    name.icn_id = 1234

    html = render_nomenclature(name: name)

    # GSD synonymy path contains "GSDspecies" not "SynSpecies"
    assert_html(html, "a[href*='GSDspecies']")
    assert_no_html(html, "a[href*='SynSpecies']")
  end

  # Normal case: `correct_spelling_id` resolves to a live Name -
  # renders a link to it.
  def test_misspelling_correct_link_renders_link_when_resolvable
    name = names(:petigera) # correct_spelling: peltigera

    html = render_nomenclature(name: name)

    assert_html(html, "a[href='#{routes.name_path(names(:peltigera).id)}']")
  end

  # Defense-in-depth case: `correct_spelling_id` is set but the
  # referenced Name is gone (no real FK constraint enforces this -
  # see Name::Merge#merge's re-snapshot-before-destroy comment for
  # the narrow race this guards against). Falls back to the bare id
  # instead of raising.
  def test_misspelling_correct_link_falls_back_to_id_when_dangling
    name = Name.new(rank: Name.ranks[:Genus], text_name: "Testia",
                    search_name: "Testia", sort_name: "Testia",
                    display_name: "**__Testia__**", user: @user)
    name.save(validate: false)
    dangling_id = Name.maximum(:id) + 1_000_000
    name.update_column(:correct_spelling_id, dangling_id)

    html = render_nomenclature(name: name.reload)

    assert_no_html(html, "a[href='#{routes.name_path(dangling_id)}']")
    assert_includes(html, dangling_id.to_s)
  end

  def routes
    Rails.application.routes.url_helpers
  end

  private

  def render_nomenclature(name:, user: nil)
    render(Views::Controllers::Names::Show::Nomenclature.new(
             name: name,
             user: user
           ))
  end
end
