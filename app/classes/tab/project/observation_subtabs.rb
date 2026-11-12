# frozen_string_literal: true

# Member-facing observation sub-tabs: Observations / Map / Images /
# Download, plus Field Slips when the project has a
# `field_slip_prefix` and Violations when it has constraints. Replaces
# the old `Projects::ObservationButtons` row -- hoisted to the
# project-banner level and rendered via
# `Views::Controllers::Projects::ObservationSubtabs` /
# `Components::NavTabs` instead of a `content_for(:observation_buttons)`
# button row.
class Tab::Project::ObservationSubtabs < Tab::Collection
  def initialize(project:, query:, controller:)
    super()
    @project = project
    @query = query
    @controller = controller
  end

  private

  def tabs
    [
      ::Tab::Project::ObservationIndex.new(project: @project),
      ::Tab::Project::ObservationMap.new(q_param: q_param),
      ::Tab::Project::ObservationImages.for(
        query: observation_query, controller: @controller
      ),
      ::Tab::Project::ObservationDownload.new(q_param: q_param),
      field_slips_tab,
      violations_tab
    ].compact
  end

  def q_param
    @controller.q_param(observation_query)
  end

  # The project's observations query when the ambient query already
  # is one scoped by this request (Observations index, Map, Download);
  # otherwise a fresh project-scoped query (e.g. the Field Slips page,
  # whose own query filters FieldSlips, not Observations).
  def observation_query
    @observation_query ||=
      if @query.is_a?(::Query::Observations)
        @query
      else
        ::Query.lookup_and_save(:Observation, projects: @project)
      end
  end

  def field_slips_tab
    return unless @project.field_slip_prefix

    ::Tab::Project::ObservationFieldSlips.new(project: @project)
  end

  def violations_tab
    return unless @project.constraints?

    ::Tab::Project::ObservationViolations.new(project: @project)
  end
end
