# frozen_string_literal: true

# The tab strip rendered in the project banner (Summary, Observations,
# Names, Locations, Species Lists, Updates, Admin). Order matters and
# matches the pre-conversion ERB / Phlex view exactly:
#
#   Summary  →  [Observations if obs.any?]
#            →  Species Lists (always when obs.any?; only when
#                              species_lists.any? otherwise)
#            →  Names
#            →  Locations
#            →  [Updates if has_targets? && is_admin?]
#            →  [Admin if is_admin?]
class Tab::Project::Banner < Tab::Collection
  def initialize(project:, user:)
    super()
    @project = project
    @user = user
  end

  private

  def tabs
    [
      Tab::Project::Summary.new(project: @project),
      *body_tabs,
      admin_tab
    ].compact
  end

  def body_tabs
    if @project.observations.any?
      with_observations
    else
      without_observations
    end
  end

  def with_observations
    [
      Tab::Project::Observations.new(project: @project),
      Tab::Project::SpeciesLists.new(project: @project),
      Tab::Project::Names.new(project: @project),
      Tab::Project::Locations.new(project: @project),
      *update_tab
    ]
  end

  def without_observations
    [
      *species_lists_tab,
      Tab::Project::Names.new(project: @project),
      Tab::Project::Locations.new(project: @project),
      *update_tab
    ]
  end

  def species_lists_tab
    return [] unless @project.species_lists.any?

    [Tab::Project::SpeciesLists.new(project: @project)]
  end

  def update_tab
    return [] unless @project.has_targets? && @project.is_admin?(@user)

    [Tab::Project::Updates.new(project: @project)]
  end

  def admin_tab
    return unless @project.is_admin?(@user)

    Tab::Project::Admin.new(project: @project)
  end
end
