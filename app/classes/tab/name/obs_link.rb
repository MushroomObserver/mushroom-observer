# frozen_string_literal: true

# Abstract base for the 5 observation-counting Tabs that appear in
# the "About this taxon" panel on a Name show page (rendered by
# `Views::Controllers::Names::Show::ObservationsMenu`):
#
#   - `Tab::Name::ObsLink::ThisName`
#   - `Tab::Name::ObsLink::OtherNames`
#   - `Tab::Name::ObsLink::AnyName`
#   - `Tab::Name::ObsLink::TaxonProposed`
#   - `Tab::Name::ObsLink::NameProposed`
#
# Each Tab knows: a translation key for its label, a Query of
# Observations to point at, and the pre-computed count of matching
# observations (carried by `Name::Observations`). Title format is
# `"#{label.t} (#{count})"`. When `count.zero?`, `linked?` returns
# false and the view renders a plain "(0)" placeholder instead of
# a link.
#
# Subclasses MUST implement:
#   #label_key      — Symbol for the link label (e.g. `:obss_of_this_name`)
#   #build_query    — returns the (saved) `Query::Observations` instance
#
# The base inherits `Tab::QueryLink`'s memoized `#query` and
# `#path` (via `controller.add_q_param(observations_path, query)`).
class Tab::Name::ObsLink < Tab::QueryLink
  def initialize(name:, count:, controller:)
    super(controller: controller)
    @name = name
    @count = count
  end

  def title
    "#{label_key.t} (#{@count})"
  end

  # Stable selector class — pins to the label key, not the
  # `<title>_(<count>)_link` slug that would change whenever the
  # count moves. Keeps test selectors robust.
  def alt_title
    label_key.to_s
  end

  # When false, the panel renders `"#{title}"` as plain text
  # without an anchor — no need to build / save the query.
  def linked?
    @count.positive?
  end

  # Data attrs read by the `filter-caption` Stimulus controller on
  # the observations index. Empty when the tab isn't linked (the
  # view doesn't render an `<a>` in that case).
  def html_options
    return {} unless linked?

    { data: {
      query_params: query.params.deep_compact_blank.to_json,
      query_record: query.record.id,
      query_alph: query.record.id.alphabetize
    } }
  end

  private

  def label_key
    raise(NotImplementedError.new("#{self.class}#label_key"))
  end

  def target_params
    observations_path
  end
end
