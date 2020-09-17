xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "project"
) do
  xml_string(xml, :title, object.title)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_html_string(xml, :summary, object.summary.to_s.tpl_nodiv)
  if !detail
    xml_minimal_object_old(xml, :creator, User, object.user_id)
  else
    xml_detailed_object_old(xml, :creator, object.user)
    admin_ids = object.admin_group.user_ids
    member_ids = object.user_group.user_ids
    xml.admins(number: admin_ids.length) do
      for user_id in admin_ids
        xml_minimal_object_old(xml, :admin, User, user_id)
      end
    end
    xml.members(number: member_ids.length) do
      for user_id in member_ids
        xml_minimal_object_old(xml, :member, User, user_id)
      end
    end
  end
end
