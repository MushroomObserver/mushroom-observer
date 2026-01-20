# frozen_string_literal: true

json.id(object.id)
json.type("field_slip")
json.code(object.code.to_s)
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
json.observation_id(object.observation_id)
if detail
  json.project(json_project(object.project)) if object.project
  json.user(json_user(object.user)) if object.user
else
  json.project_id(object.project_id)
  json.user_id(object.user_id)
end
