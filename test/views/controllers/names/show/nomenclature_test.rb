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

  private

  def render_nomenclature(name:, user: nil)
    render(Views::Controllers::Names::Show::Nomenclature.new(
             name: name,
             user: user
           ))
  end
end
