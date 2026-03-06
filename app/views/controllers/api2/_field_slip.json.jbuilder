# frozen_string_literal: true

json.id(object.id)
json.type("field_slip")
json.code(object.code.to_s)
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
if detail
  json.observation_ids(object.observation_ids) \
    if object.observations.any?
  json.project(json_project(object.project)) if object.project
  json.user(json_user(object.user)) if object.user
else
  json.observation_ids(object.observation_ids) \
    if object.observations.any?
  json.project_id(object.project_id)
  json.user_id(object.user_id)
end
