json.id              object.id
json.type            "user"
json.login_name      object.login
json.legal_name      object.legal_name
json.joined          object.created_at
json.verified        object.verified
json.last_login      object.last_login
json.last_activity   object.last_activity
json.contribution    object.contribution
json.notes           (object.notes || "").tpl_nodiv
json.mailing_address (object.mailing_address || "").to_s.html_to_ascii
if !detail
  json.location_id object.location_id
  json.image_id    object.image_id
else
  json.location { json_detailed_object(json, object.location) }
  json.image    { json_detailed_object(json, object.image) }
  if @user == object or
     # (special exception: show API keys of new user when API creates new user)
     @show_api_keys_for_new_user
    if object.api_keys.any?
      json.api_keys object.api_keys.map do |api_key|
        json_detailed_object(json, api_key)
      end
    end
  end
end
