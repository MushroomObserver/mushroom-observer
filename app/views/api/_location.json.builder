json.id               object.id
json.type             "location"
json.name             object.text_name
json.latitude_north   object.north
json.latitude_south   object.south
json.longitude_east   object.east
json.longitude_west   object.west
json.altitude_maximum object.high
json.altitude_minimum object.low
json.notes            object.notes.to_s.tpl_nodiv
json.created_at       object.created_at.try(&:utc)
json.updated_at       object.updated_at.try(&:utc)
json.number_of_views  object.num_views
json.last_viewed      object.last_view.try(&:utc)
json.ok_for_export    object.ok_for_export ? true : false
