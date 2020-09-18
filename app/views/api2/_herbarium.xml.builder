# frozen_string_literal: true

xml.tag!(
  tag,
  id: object.id,
  url: object.show_url,
  type: "herbarium"
) do
  xml_string(xml, :code, object.code)
  xml_string(xml, :name, object.name)
  xml_string(xml, :email, object.email)
  xml_string(xml, :address, object.mailing_address)
  xml_html_string(xml, :description, object.description.to_s.tpl_nodiv)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  if !detail
    xml_minimal_object(xml, :location, :location, object.location_id)
    xml_minimal_object(xml, :personal_user, :user, object.personal_user_id)
  else
    xml_detailed_object(xml, :location, object.location)
    xml_detailed_object(xml, :personal_user, object.personal_user)
  end
end
