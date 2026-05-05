# frozen_string_literal: true

json.id(object.id)
json.type("occurrence")
json.primary_observation_id(object.primary_observation_id)
json.has_specimen(object.has_specimen ? true : false)
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
json.observation_ids(object.observations.map(&:id))
if detail
  json.owner(json_user(object.user))
  json.field_slip(json_field_slip(object.field_slip)) \
    if object.field_slip
  json.observations(object.observations.map do |obs|
    { id: obs.id, name: obs.name&.text_name,
      date: obs.when, primary: obs.id == object.primary_observation_id }
  end)
else
  json.owner_id(object.user_id)
  json.field_slip_id(object.field_slip_id) if object.field_slip_id
end
