# frozen_string_literal: true

# "Observations of subtaxa (N)" link in the Name-show
# observations-menu panel. Wraps the controller-built
# `@subtaxa_query` (`Query::Observations` filtered to subtaxa of
# this Name) and points at the Observations index. Renders only
# when this Name has subtaxa (the controller sets `@has_subtaxa`
# to a positive Integer when `@name.at_or_below_genus?`).
#
# Unlike the other 5 `Tab::Name::ObsLink::*` subclasses, the query
# is supplied by the controller rather than built locally — the
# observations-subtaxa query is also used elsewhere on the page
# (header pager scope), so duplicating the construction would be
# wasteful. Inherits `Tab::QueryLink` directly rather than
# `Tab::Name::ObsLink` -- the other 5 build a plain route-helper
# path with no Query, so they no longer share a base with this one.
class Tab::Name::ObsLink::Subtaxa < Tab::QueryLink
  def initialize(name:, count:, controller:, query:)
    super(controller: controller)
    @name = name
    @count = count
    @injected_query = query
  end

  def title
    "#{label_key.t} (#{@count})"
  end

  def alt_title
    label_key.to_s
  end

  def linked?
    @count.positive?
  end

  private

  def label_key
    :show_subtaxa_obss
  end

  def build_query
    @injected_query
  end

  def target_params
    observations_path
  end
end
