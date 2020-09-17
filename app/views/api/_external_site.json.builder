json.id      object.id
json.type    "external_site"
json.name    object.name
if !detail
  json.project_id object.project_id
else
  json.project { json_detailed_object(json, object.project) }
end
