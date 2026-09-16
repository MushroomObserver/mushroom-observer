# frozen_string_literal: true

# Abstract base for Tabs whose `#path` is built by appending the
# tab's saved Query as the `q` param of a target URL or
# `{controller:, action:}` Hash.
#
# Why a base class:
#
#   - Multiple Tab families share this "save a query, build an
#     `add_q_param(target, query)` URL" pattern — `Tab::RelatedQuery`
#     (cross-model "related index" links) and
#     `Tab::Name::ObsLink::Subtaxa` (a subtaxa-observations link
#     wrapping a query the controller already built for other page
#     chrome). Centralizing the boilerplate here means new
#     query-link Tabs only declare their `#build_query` and
#     `#target_params`.
#   - `#query` is memoized in the base. A subclass whose
#     `#build_query` saves a new record (`query.save`) must not do
#     that twice if `#path` is read more than once — without
#     memoization, a second read would re-save unnecessarily.
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
