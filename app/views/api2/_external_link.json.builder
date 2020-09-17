# frozen_string_literal: true

json.id(object.id)
json.type("external_link")
json.url(object.url.to_s)
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
json.observation_id(object.observation_id)
if !detail
  json.owner_id(object.user_id
  json.external_site_id(object.external_site.id)
else
  json.owner(json_user(object.user))
  json.external_site(json_external_site(object.external_site))
end
