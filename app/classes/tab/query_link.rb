# frozen_string_literal: true

# Abstract base for Tabs whose `#path` is built by appending the
# tab's saved Query as the `q` param of a target URL or
# `{controller:, action:}` Hash.
#
# Why a base class:
#
#   - Multiple Tab families share this "save a query, build an
#     `add_q_param(target, query)` URL" pattern — `Tab::RelatedQuery`
#     (cross-model "related index" links) and the obs-counting Tabs
#     under `Tab::Name::ObsLink::*`. Centralizing the boilerplate
#     here means new query-link Tabs only declare their `#query` and
#     `#target_params`.
#   - `#query` is memoized in the base. Subclasses that have save
#     side-effects (the obs-link Tabs call `query.save` in
#     `#build_query` so the `q` param can carry a stable record id)
#     must not be called twice — the view typically asks for both
#     `#path` and `#html_options[:data]`, each of which reads
#     `query`. Without memoization the same query would be saved
#     twice, creating two `QueryRecord` rows.
#
# Subclasses MUST implement:
#
#   #build_query    — returns a `Query` instance. May `.save` it
#                     before returning when the resulting URL needs
#                     a stable query record (the q-param shape that
#                     the filter-caption Stimulus controller reads
#                     from `data-query-{params,record,alph}`).
#   #target_params  — either a String (a route helper result like
#                     `observations_path`) or a Hash
#                     `{controller:, action:}`. Forwarded to
#                     `controller.add_q_param(target_params, query)`.
#
# Subclasses inherit a working `#path` and must still implement
# `#title` (per `Tab::Base`).
class Tab::QueryLink < Tab::Base
  def initialize(controller:)
    super()
    @controller = controller
  end

  # Memoized so subclasses with save side-effects in `#build_query`
  # don't double-save when both `#path` and `#html_options` access
  # the query.
  def query
    @query ||= build_query
  end

  def path
    @controller.add_q_param(target_params, query)
  end

  private

  def build_query
    raise(NotImplementedError.new("#{self.class}#build_query"))
  end

  def target_params
    raise(NotImplementedError.new("#{self.class}#target_params"))
  end
end
