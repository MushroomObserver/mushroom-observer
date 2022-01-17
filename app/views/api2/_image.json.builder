# frozen_string_literal: true

json.id(object.id)
json.type("image")
json.date(object.when)
json.copyright_holder(object.copyright_holder.to_s)
json.notes(object.notes.to_s.tpl_nodiv) if object.notes.present?
json.quality(object.vote_cache) if object.vote_cache.present?
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
json.original_name(object.original_name.to_s) \
  if check_permission(object) && object.original_name.present?
json.number_of_views(object.num_views) if object.num_views.present?
json.last_viewed(object.last_view.try(&:utc)) if object.last_view.present?
json.ok_for_export(object.ok_for_export ? true : false)
json.license(object.license.display_name.to_s)
json.content_type(object.content_type.to_s)
json.width(object.width) if object.width.present?
json.height(object.height) if object.height.present?
json.original_url(object.original_url)
if !detail
  json.owner_id(object.user_id)
else
  json.owner(json_user(object.user))
  json.files((Image.all_sizes + [:original]).map do |size|
    object.send("#{size}_url")
  end)
  json.observation_idsr(object.observation_ids)
end
