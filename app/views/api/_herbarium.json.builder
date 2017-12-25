json.id          object.id
json.type        "herbarium"
json.code        object.code
json.name        object.name
json.email       object.email
json.address     object.mailing_address.to_s.strip_html
json.description object.description.to_s.tpl_nodiv
json.created_at  object.created_at.utc
json.updated_at  object.updated_at.utc
if !detail
  json.location_id      object.location_id
  json.personal_user_id object.personal_user_id
else
  json.location      { json_detailed_object(json, object.location) }
  json.personal_user { json_detailed_object(json, object.personal_user) }
end
