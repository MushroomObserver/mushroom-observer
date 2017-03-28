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
  xml_boolean(xml, :is_collection_location, true) if object.is_collection_location
  xml_detailed_object(xml, :consensus_name, object.name)
  xml_confidence_level(xml, :confidence, object.vote_cache)
  xml_html_string(xml, :notes, object.notes.to_s.tpl_nodiv)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_integer(xml, :number_of_views, object.num_views)
  xml_datetime(xml, :last_viewed, object.last_view)
  if detail
    xml.namings(:number => object.namings.length) do
      for naming in object.namings
        xml_detailed_object(xml, :naming, naming)
      end
    end
    for image in object.images
      # Do it this way, else will not use eager-loaded image instance.
      if image.id == object.thumb_image_id
        xml_detailed_object(xml, :primary_image, image)
      end
    end
    xml.images(:number => object.images.length - 1) do
      for image in object.images
        if image.id != object.thumb_image_id
          xml_detailed_object(xml, :image, image)
        end
      end
    end
    xml.comments(:number => object.comments.length) do
      for comment in object.comments
        xml_detailed_object(xml, :comment, comment)
      end
    end
  end
end
