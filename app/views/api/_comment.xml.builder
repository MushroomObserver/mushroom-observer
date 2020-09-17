xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "comment"
) do
  xml_html_string(xml, :summary, object.summary.to_s.tl)
  xml_html_string(xml, :content, object.comment.to_s.tpl_nodiv)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  if !detail
    xml_minimal_object_old(xml, :owner, User, object.user_id)
    xml_minimal_object_old(xml, :object, object.target_type, object.target_id)
  else
    xml_detailed_object_old(xml, :owner, object.user)
    xml_detailed_object_old(xml, :object, object.target)
  end
end
