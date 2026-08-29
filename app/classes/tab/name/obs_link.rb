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
# Each Tab knows: a translation key for its label, a query_attr on
# Query::Observations to filter by, and the pre-computed count of
# matching observations (carried by `Name::Observations` -- one
# query total for all 5 counts, computed before any of these Tabs
# are built). Building the path here is plain string formatting;
# it does not query the database. Title format is `"#{label.t}
# (#{count})"`. When `count.zero?`, `linked?` returns false and the
# view renders a plain "(0)" placeholder instead of a link.
#
# Subclasses MUST implement:
#   #label_key      — Symbol for the link label (e.g. `:obss_of_this_name`)
#   #filter_attr    — Query::Observations attr for this Tab's preset
#                      (e.g. `:this_name`, `:any_name`)
#
# `Tab::Name::ObsLink::Subtaxa` is a separate case, not a subclass
# of this base -- it wraps a Query the controller already built for
# other page chrome, so it inherits `Tab::QueryLink` instead.
class Tab::Name::ObsLink < Tab::Base
  def initialize(name:, count:)
    super()
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
  # without an anchor.
  def linked?
    @count.positive?
  end

  def path
    observations_path(filter_attr => @name.id)
  end

  private

  def label_key
    raise(NotImplementedError.new("#{self.class}#label_key"))
  end

  def filter_attr
    raise(NotImplementedError.new("#{self.class}#filter_attr"))
  end
end
