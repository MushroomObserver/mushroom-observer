# frozen_string_literal: true

# Shared `effective_query` -- the Query the user is navigating,
# explicit `query:` prop when given, else the controller's
# `current_query`. Mixed into both Components::Map and
# Components::Map::Popup, which each need the same fallback for
# minting `?q=…` on their own links.
module Components::Map::EffectiveQuery
  private

  def effective_query
    @effective_query ||= @query || current_query
  end
end
