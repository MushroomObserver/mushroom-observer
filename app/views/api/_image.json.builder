json.id               object.id
json.type             "image"
json.date             object.when
json.copyright_holder object.copyright_holder
json.notes            object.notes.to_s.tpl_nodiv
json.quality          object.vote_cache
json.created_at       object.created_at.utc
json.updated_at       object.updated_at.utc
json.original_name    object.original_name if check_permission(object)
json.number_of_views  object.num_views
json.last_viewed      object.last_view.try(&:utc)
json.ok_for_export    object.ok_for_export ? true : false
if !detail
  json.license_id object.license_id
  json.owner_id   object.user_id
else
  json.license         object.license.display_name
  json.owner           { json_detailed_object(json, object.user) }
  json.observation_ids object.observation_ids
  json.files           (Image.all_sizes + [:original]).map do |size|
    object.send("#{size}_url")
  end
end
