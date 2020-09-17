json.id              object.id
json.type            "user"
json.login_name      object.login.to_s if object.login.present?
json.legal_name      object.legal_name.to_s if object.legal_name.present?
json.joined          object.created_at.try(&:utc)
json.verified        object.verified.try(&:utc)
json.last_login      object.last_login.try(&:utc)
json.last_activity   object.last_activity.try(&:utc)
json.contribution    object.contribution if object.contribution.present?
json.notes           object.notes.to_s.tpl_nodiv if object.notes.present?
json.mailing_address object.mailing_address.to_s \
                       if object.mailing_address.present?
if !detail
  json.location_id   object.location_id if object.location_id
  json.image_id      object.image_id if object.image_id
else
  json.location      json_location(object.location) if object.location
  json.image         json_image(object.image) if object.image
  if @user == object or
     # (special exception: show API key of new user when API creates new user)
     @show_api_keys_for_new_user
    if object.api_keys.any?
      json.api_keys(object.api_keys.map { |x| json_api_key(x) })
    end
  end
end
