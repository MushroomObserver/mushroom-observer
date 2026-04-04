# frozen_string_literal: true

xml.tag!(
  tag,
  id: object.id,
  url: occurrence_url(object.id),
  type: "occurrence"
) do
  xml_integer(xml, :primary_observation_id, object.primary_observation_id)
  xml_boolean(xml, :has_specimen, object.has_specimen)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  if object.observations.any?
    xml.observations(number: object.observations.length) do
      object.observations.each do |obs|
        xml_minimal_object(xml, :observation, :observation, obs.id)
      end
    end
  end
  if detail
    xml_detailed_object(xml, :owner, object.user)
    xml_detailed_object(xml, :field_slip, object.field_slip) \
      if object.field_slip
  else
    xml_minimal_object(xml, :owner, :user, object.user_id)
    if object.field_slip_id
      xml_minimal_object(xml, :field_slip, :field_slip,
                         object.field_slip_id)
    end
  end
end
