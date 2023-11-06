# frozen_string_literal: true

class ProjectLatLongs
  attr_accessor :query

  def initialize
    self.query = tables[:observations]
    add_joins
    add_project
    add_conditions
  end

  def vals
    Observation.connection.select_rows(query.to_sql).uniq
  end

  private

  def tables
    @tables ||= {
      observations: Observation.arel_table,
      project_observations: ProjectObservation.arel_table,
      project_members: ProjectMember.arel_table,
      projects: Project.arel_table,
      user_group_users: UserGroupUser.arel_table
    }
  end

  def add_joins
    join_table(:project_observations, :observation_id,
               attribute(:observations, :id))
    join_table(:project_members, :user_id,
               attribute(:observations, :user_id))
    join_table(:projects, :id,
               attribute(:project_observations, :project_id))
    join_table(:user_group_users, :user_group_id,
               attribute(:projects, :admin_group_id))
  end

  def join_table(join_name, join_field, attribute)
    table = tables[join_name]
    join_attribute = table[join_field]
    self.query = query.join(table).on(join_attribute.eq(attribute))
  end

  def attribute(table_name, field)
    tables[table_name][field]
  end

  def add_project
    query.project(attribute(:observations, :id),
                  attribute(:observations, :lat),
                  attribute(:observations, :long))
  end

  def add_conditions
    query.where(attribute(:project_members,
                          :project_id).eq(attribute(:projects, :id)))
    query.where(attribute(:user_group_users,
                          :user_id).not_eq(attribute(:project_members,
                                                     :user_id)))
    query.where(attribute(:project_members, :trusted).eq(1))
    query.where(attribute(:observations, :gps_hidden).eq(1))
    query.where(attribute(:user_group_users, :user_id).eq(User.current_id))
  end
end
