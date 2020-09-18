# frozen_string_literal: true

json.id(object.id)
json.type("herbarium_record")
json.initial_determination(object.initial_det.to_s) \
  if object.initial_det.present?
json.accession_number(object.accession_number.to_s) \
  if object.accession_number.present?
json.notes(object.notes.to_s.tpl_nodiv) if object.notes.present?
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
if !detail
  json.herbarium_id(object.herbarium_id)
  json.user_id(object.user_id)
else
  json.herbarium(json_herbarium(object.herbarium))
  json.user(json_user(object.user))
  json.observation_ids(object.observation_ids)
end
