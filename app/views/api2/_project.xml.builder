# frozen_string_literal: true

xml.tag!(
  tag,
  id: object.id,
  url: object.show_url,
  type: "project"
) do
  xml_string(xml, :title, object.title)
  xml_html_string(xml, :summary, object.summary.to_s.tpl_nodiv)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  if !detail
    xml_minimal_object(xml, :creator, :user, object.user_id)
  else
    xml_detailed_object(xml, :creator, object.user)
    if object.comments.any?
      xml.comments(number: object.comments.to_a.count) do
        object.comments.each do |comment|
          xml_detailed_object(xml, :comment, comment)
        end
      end
    end
  end
end
