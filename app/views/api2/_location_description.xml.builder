# frozen_string_literal: true

xml.tag!(
  tag,
  id: object.id,
  url: object.show_url,
  type: "location_description"
) do
  xml_integer(xml, :location_id, object.location_id)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_integer(xml, :number_of_views, object.num_views)
  xml_datetime(xml, :last_viewed, object.last_view)
  xml_boolean(xml, :ok_for_export, true) if object.ok_for_export
  xml_string(xml, :source_type, object.source_type)
  xml_string(xml, :source_name, object.source_name)
  xml_string(xml, :license, object.license.try(&:display_name))
  xml_boolean(xml, :public, true) if object.public
  xml_string(xml, :locale, object.locale)
  xml_string(xml, :gen_desc, object.gen_desc)
  xml_string(xml, :ecology, object.ecology)
  xml_string(xml, :species, object.species)
  xml_string(xml, :notes, object.notes)
  xml_string(xml, :refs, object.refs)
end
