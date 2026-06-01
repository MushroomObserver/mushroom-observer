# frozen_string_literal: true

# Extra action-nav links shown on the observations index when the
# user landed via a typed-but-unknown location string (`?where=...`).
# Caller passes `where:` (resolved from `params[:where]` or
# `query.params[:search_where]`) and `q_param:`. Replaces
# `Tabs::ObservationsHelper#observations_at_where_tabs`.
class Tab::Observation::AtWhereActions < Tab::Collection
  def initialize(where:, q_param: nil)
    super()
    @where = where
    @q_param = q_param
  end

  private

  def tabs
    [
      Tab::Observation::DefineLocation.new(where: @where,
                                           q_param: @q_param),
      Tab::Observation::AssignUndefinedLocation.new(where: @where,
                                                    q_param: @q_param),
      Tab::Location::Index.new
    ]
  end
end
