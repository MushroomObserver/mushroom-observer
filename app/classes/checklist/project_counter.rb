# frozen_string_literal: true

class Checklist::ProjectCounter
  def initialize(project)
    @project = project
    @names = Name.arel_table
    @observations = Observation.arel_table
    @project_observations = ProjectObservation.arel_table
  end

  def joins
    join_observations = @names.
                        join(@observations).
                        on(@observations[:name_id].eq(@names[:id]))
    join_observations.
      join(@project_observations).
      on(@project_observations[:observation_id].eq(@observations[:id]))
  end

  def where_conditions
    # Build the where conditions
    @project_observations[:project_id].eq(@project.id).
      and(@names[:id].eq(@observations[:name_id]))
  end

  def query
    # Build the entire AREL query
    joins.
      where(where_conditions).
      group(@names[:text_name]).
      project(@names[:text_name], Arel.star.count)
  end

  def counts
    ActiveRecord::Base.connection.execute(query.to_sql).to_h
  end
end
