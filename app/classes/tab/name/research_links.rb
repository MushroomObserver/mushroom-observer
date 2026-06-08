# frozen_string_literal: true

# Collection of external research-site link tabs shown in the
# right column of the "About this taxon" panel on a Name show
# page (Index Fungorum / MycoBank type references live on the
# nomenclature panel instead).
#
# Composes (in display order):
#
#   - `Tab::Name::AscomyceteOrg` (only when this Name's classification
#                                 includes the Ascomycota phylum)
#   - `Tab::Name::Eol`           (only when this Name has an EOL URL)
#   - `Tab::Name::Gbif`
#   - `Tab::Name::UserGoogleImages`
#   - `Tab::Name::GoogleSearch`
#   - `Tab::Name::Inat`
#   - `Tab::Name::MushroomExpert` / `Tab::Name::Mycoportal` (only when
#                                  this Name is searchable in the
#                                  fungal-registry network)
#   - `Tab::Name::NcbiNucleotide`
#   - `Tab::Name::Wikipedia`
#
# `Views::Controllers::Names::Show::ObservationsMenu` consumes via
# `each` — no orchestration in the view, just iteration.
class Tab::Name::ResearchLinks < Tab::Collection
  ASCOMYCOTA_RE = /Phylum: _Ascomycota_/

  def initialize(name:, user: nil)
    super()
    @name = name
    @user = user
  end

  private

  def tabs
    [
      ascomycota_tab,
      eol_tab,
      Tab::Name::Gbif.new(name: @name),
      Tab::Name::UserGoogleImages.new(name: @name, user: @user),
      Tab::Name::GoogleSearch.new(name: @name),
      Tab::Name::Inat.new(name: @name),
      *registry_tabs,
      Tab::Name::NcbiNucleotide.new(name: @name),
      Tab::Name::Wikipedia.new(name: @name)
    ].compact
  end

  def ascomycota_tab
    return nil unless @name.classification&.match?(ASCOMYCOTA_RE)

    Tab::Name::AscomyceteOrg.new(name: @name)
  end

  def eol_tab
    return nil unless @name.eol_url

    Tab::Name::Eol.new(name: @name)
  end

  def registry_tabs
    return [] unless @name.searchable_in_registry?

    [
      Tab::Name::MushroomExpert.new(name: @name),
      Tab::Name::Mycoportal.new(name: @name)
    ]
  end
end
