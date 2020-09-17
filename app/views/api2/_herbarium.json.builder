json.id                 object.id
json.type               "herbarium"
json.code               object.code.to_s if object.code.present?
json.name               object.name.to_s if object.name.present?
json.email              object.email.to_s if object.email.present?
json.address            object.mailing_address.to_s.strip_html \
                          if object.mailing_address.present?
json.description        object.description.to_s.tpl_nodiv \
                          if object.description.present?
json.created_at         object.created_at.try(&:utc)
json.updated_at         object.updated_at.try(&:utc)
if !detail
  json.location_id      object.location_id if object.location_id
  json.personal_user_id object.personal_user_id if object.personal_user_id
else
  json.location         json_location(object.location) if object.location
  json.personal_user    json_user(object.personal_user) if object.personal_user
end
