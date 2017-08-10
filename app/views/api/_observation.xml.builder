xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "observation"
) do
  xml_detailed_object(xml, :owner, object.user)
  xml_date(xml, :date, object.when)
  if object.location
    xml_detailed_object(xml, :location, object.location)
  else
    xml_undefined_location(xml, :location, object.where)
  end
  xml_latitude(xml, :latitude, object.lat)
  xml_longitude(xml, :longitude, object.long)
  xml_altitude(xml, :altitude, object.alt)
  xml_boolean(xml, :specimen_available, true) if object.specimen
  if object.is_collection_location
    xml_boolean(xml, :is_collection_location, true)
  end
  xml_detailed_object(xml, :consensus_name, object.name)
  xml_confidence_level(xml, :confidence, object.vote_cache)
  xml_html_string(xml, :notes, object.notes.to_s.tpl_nodiv)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_integer(xml, :number_of_views, object.num_views)
  xml_datetime(xml, :last_viewed, object.last_view)
  if detail
    xml.sequences(number: object.sequences.length) do
      object.sequences.each do |sequence|
        xml_detailed_object(xml, :sequence, sequence)
      end
    end
    xml.notes do
      object.notes.each do |key, value|
        xml.notes_part do
          xml_string(xml, :key, key)
          xml_html_string(xml, :value, value.tl)
        end
      end
    end
    xml_datetime(xml, :created_at, object.created_at)
    xml_datetime(xml, :updated_at, object.updated_at)
    xml_integer(xml, :number_of_views, object.num_views)
    xml_datetime(xml, :last_viewed, object.last_view)
    xml.namings(number: object.namings.length) do
      object.namings.each do |naming|
        xml_detailed_object(xml, :naming, naming, true)
      end
    end
    object.images.each do |image|
      # Do it this way, else will not use eager-loaded image instance.
      next unless image.id == object.thumb_image_id
      xml_detailed_object(xml, :primary_image, image)
    end
    xml.images(number: object.images.length - 1) do
      object.images.each do |image|
        next if image.id == object.thumb_image_id
        xml_detailed_object(xml, :image, image)
      end
    end
    xml.comments(number: object.comments.length) do
      object.comments.each do |comment|
        xml_detailed_object(xml, :comment, comment)
      end
    end
  end
end
