# frozen_string_literal: true

json.id(object.id)
json.type("external_site")
json.name(object.name.to_s)
if detail
  json.project(json_project(object.project))
else
  json.project_id(object.project_id)
end
