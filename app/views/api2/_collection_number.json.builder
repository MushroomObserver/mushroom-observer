# frozen_string_literal: true

json.id(object.id)
json.type("collection_number")
json.collector(object.name.to_s) if object.name.present?
json.number(object.number.to_s) if object.number.present?
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
if !detail
  json.user_id(object.user_id)
else
  json.user(json_user(object.user))
  json.observation_ids(object.observation_ids) if object.observation_ids.any?
end
