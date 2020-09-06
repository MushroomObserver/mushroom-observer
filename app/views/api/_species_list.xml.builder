xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "species_list"
) do
  xml_string(xml, :title, object.title)
  xml_html_string(xml, :notes, object.notes.to_s.tpl_nodiv)
  xml_date(xml, :date, object.when)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  if !detail
    xml_minimal_location(xml, :location, object.location_id, object.where)
    xml_minimal_object(xml, :owner, :user, object.user_id)
  else
    xml_detailed_location(xml, :location, object.location, object.where)
    xml_detailed_object(xml, :owner, object.user)
    if object.comments.any?
      xml.comments(number: object.comments.count) do
        for comment in object.comments
          xml_detailed_object(xml, :comment, comment)
        end
      end
    end
  end
end
