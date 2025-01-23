# frozen_string_literal: true

# Helper methods for turning Query parameters into AR conditions.
module Query::Scopes::Joining
  def add_join_to_names
    return unless [Name, Observation, Image, Location].includes?(model)

    @scopes = case model
              when Name
                @scopes
              when Observation
                @scopes.joins(:name)
              else
                @scopes.joins(observations: :name)
              end
  end

  def add_join_to_users
    return unless [Name, Observation, Image, Location].includes?(model)

    @scopes = case model
              when Observation
                @scopes.joins(:user)
              else
                @scopes.joins(observations: :user)
              end
  end

  def add_join_to_locations
    unless [Name, Observation, Image, Location, Sequence].includes?(model)
      return
    end

    @scopes = case model
              when Location
                @scopes
              when Observation
                @scopes.left_outer_joins(:location)
              else
                @scopes.joins(:observations).left_outer_joins(:location)
              end
  end

  def add_join_to_searchable_observation_content
    content_sources = if model == Observation
                        :comments
                      else
                        { observations: :comments }
                      end
    @scopes = @scopes.joins(content_sources)
  end
end
