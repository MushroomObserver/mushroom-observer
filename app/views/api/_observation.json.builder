json.id                     object.id
json.type                   "observation"
json.date                   object.when
json.latitude               object.lat
json.longitude              object.long
json.altitude               object.alt
json.specimen_available     object.specimen ? true : false
json.is_collection_location object.is_collection_location ? true : false
json.confidence             object.vote_cache
json.notes                  object.notes.to_s.tpl_nodiv
json.created_at             object.created_at
json.updated_at             object.updated_at
json.number_of_views        object.num_views
json.last_viewed            object.last_view
json.owner                  { json_detailed_object(json, object.user) }
json.consensus              { json_detailed_object(json, object.name) }
if object.location
  json.location { json_detailed_object(json, object.location) }
else
  json.location_name object.where
end
if detail
  json.namings object.namings.map do |naming|
    json_detailed_object(json, naming, true)
  end
  other_images = []
  object.images.each do |image|
    # Do it this way, else will not use eager-loaded image instance.
    if image.id == object.thumb_image_id
      json.primary_image { json_detailed_object(json, image) }
    else
      other_images << image
    end
  end
  json.images other_images.map do |image|
    json_detailed_object(json, image)
  end
  json.comments object.comments.map do |comment|
    json_detailed_object(json, comment)
  end
end
