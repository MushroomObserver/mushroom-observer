# frozen_string_literal: true

# "Subtaxa" link in the Name-show classification panel. Points at
# the Names index filtered to the immediate children of this Name
# (the `@children_query` the controller built for the
# classification + lifeform panels).
#
# Label switches between "Species" (when this Name is at-or-below
# Genus but above Species) and "Observations of subtaxa" (the
# generic fallback) — the same logic the legacy
# `NamesHelper#name_subtaxa_query_link` had.
class Tab::Name::Subtaxa < Tab::QueryLink
  def initialize(name:, children_query:, controller:)
    super(controller: controller)
    @name = name
    @children_query = children_query
  end

  def title
    :show_object.t(type: type_key)
  end

  def alt_title
    "subtaxa"
  end

  private

  def type_key
    if @name.at_or_below_genus? && !@name.at_or_below_species?
      :rank_species
    else
      :show_subtaxa_obss
    end
  end

  def build_query
    @children_query
  end

  def target_params
    names_path
  end
end
