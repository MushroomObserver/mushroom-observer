xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "image"
) do
  xml_date(xml, :date, object.when)
  xml_string(xml, :copyright_holder, object.copyright_holder)
  xml_html_string(xml, :notes, object.notes.to_s.tpl_nodiv)
  xml_image_quality(xml, :quality, object.vote_cache)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_integer(xml, :number_of_views, object.num_views)
  xml_datetime(xml, :last_viewed, object.last_view)
  xml_boolean(xml, :ok_for_export, true) if object.ok_for_export
  xml_string(xml, :original_name, object.original_name) if check_permission(object)
  xml.observations(number: object.observations.length) do
    for id in object.observation_ids
      xml_minimal_object(xml, :observation, Observation, id)
    end
  end
  if !detail
    xml_minimal_object(xml, :license, License, object.license_id)
    xml_minimal_object(xml, :owner, User, object.user_id)
  else
    xml_detailed_object(xml, :license, object.license)
    xml_detailed_object(xml, :owner, object.user)
    xml.files(number: Image.all_sizes.length + 1) do
      for size in Image.all_sizes + [:original]
        xml_image_file(xml, object, size)
      end
    end
  end
end
