json.id               object.id
json.type             "location"
json.name             object.text_name.to_s
json.latitude_north   object.north if object.north.present?
json.latitude_south   object.south if object.south.present?
json.longitude_east   object.east if object.east.present?
json.longitude_west   object.west if object.west.present?
json.altitude_maximum object.high if object.high.present?
json.altitude_minimum object.low if object.low.present?
json.notes            object.notes.to_s.tpl_nodiv if object.notes.present?
json.created_at       object.created_at.try(&:utc)
json.updated_at       object.updated_at.try(&:utc)
json.number_of_views  object.num_views
json.last_viewed      object.last_view.try(&:utc)
json.ok_for_export    object.ok_for_export ? true : false
if detail && object.comments.any?
  json.comments(object.comments.map { |x| json_comment(x) })
end
