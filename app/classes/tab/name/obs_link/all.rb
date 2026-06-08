# frozen_string_literal: true

# Collection of all observation-counting links shown in the "About
# this taxon" panel of the Name show page. Composes the 5 standard
# `Tab::Name::ObsLink::*` subclasses + the optional
# `Tab::Name::ObsLink::Subtaxa` when this Name has subtaxa.
#
# `Views::Controllers::Names::Show::ObservationsMenu` consumes via
# `each` — no orchestration logic in the view, just iteration.
class Tab::Name::ObsLink::All < Tab::Collection
  # Each standard obs-link tab is `[Tab class, count method on
  # `Name::Observations`]`. The count comes from the PORO that
  # was already loaded for the page so it isn't re-queried here.
  SPECS = [
    [Tab::Name::ObsLink::ThisName, :of_taxon_this_name],
    [Tab::Name::ObsLink::OtherNames, :of_taxon_other_names],
    [Tab::Name::ObsLink::AnyName, :of_taxon_any_name],
    [Tab::Name::ObsLink::TaxonProposed, :where_taxon_proposed],
    [Tab::Name::ObsLink::NameProposed, :where_name_proposed]
  ].freeze

  def initialize(name:, obss:, controller:,
                 subtaxa_query: nil, has_subtaxa: 0)
    super()
    @name = name
    @obss = obss
    @controller = controller
    @subtaxa_query = subtaxa_query
    @has_subtaxa = has_subtaxa
  end

  private

  def tabs
    [*standard_tabs, subtaxa_tab].compact
  end

  def standard_tabs
    SPECS.map do |klass, count_method|
      klass.new(name: @name, count: @obss.send(count_method).size,
                controller: @controller)
    end
  end

  # Only rendered when the controller flagged this Name as having
  # subtaxa observations (positive Integer).
  def subtaxa_tab
    return nil unless @has_subtaxa.positive?

    Tab::Name::ObsLink::Subtaxa.new(
      name: @name, count: @has_subtaxa, query: @subtaxa_query,
      controller: @controller
    )
  end
end
