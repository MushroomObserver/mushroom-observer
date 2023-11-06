# frozen_string_literal: true

module Report
  # 2:: observations.lat
  # 3:: observations.long
  class ProjectTweaker
    QUERY = "SELECT DISTINCT obs.id, obs.lat, obs.long
FROM observations obs,
project_observations pobs,
project_members  pms,
projects ps,
user_group_users ugu
WHERE obs.id = pobs.observation_id
AND pms.user_id = obs.user_id
AND ps.id = pobs.project_id
AND ps.id = pms.project_id
AND ugu.user_id = 1
AND ugu.user_group_id = ps.admin_group_id
AND pms.trusted = '1'
AND obs.gps_hidden = '1'
AND ugu.user_id != pms.user_id"

    def initialize
      self.query = tables[:observations]
      add_joins
      add_project
      add_conditions
    end

    def add_joins
      join_table(:project_observations, :observation_id,
                 attribute(:observations, :id))
      join_table(:project_members, :user_id,
                 attribute(:observations, :user_id))
      join_table(:projects, :id,
                 attribute(:project_observations, :project_id))
    end

    def join_table(join_name, join_field, attribute)
      table = tables[join_name]
      join_attribute = table[join_field]
      self.query = query.join(table).on(join_attribute.eq(attribute))
    end

    def attribute(table_name, field)
      tables[table_name][field]
    end

    def tweak(row)
      row
    end
  end
end
