# frozen_string_literal: true

# "Define location" link shown on observations-at-where pages, when
# the user reached the page via a typed-but-unknown location string.
# Caller resolves `where:` (typically from `params[:where]` or
# `query.params[:search_where]`).
class Tab::Observation::DefineLocation < Tab::Base
  def initialize(where:, q_param: nil)
    super()
    @where = where
    @q_param = q_param
  end

  def title
    :list_observations_location_define.l
  end

  def path
    with_q_param(new_location_path(where: @where), @q_param)
  end
end
