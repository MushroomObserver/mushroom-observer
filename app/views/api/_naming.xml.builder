xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "naming"
) do
  xml_confidence_level(xml, :confidence, object.vote_cache)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_detailed_object_old(xml, :name, object.name)
  xml_minimal_object_old(xml, :owner, User, object.user_id)
  xml_minimal_object_old(xml, :observation, Observation, object.observation_id)
  if detail
    xml.votes(number: object.votes.length) do
      object.votes.each do |vote|
        xml_detailed_object_old(xml, :vote, vote)
      end
    end
  end
  reasons = object.get_reasons.select(&:used?)
  if reasons.any?
    xml.reasons(number: reasons.length) do
      reasons.each do |reason|
        xml_naming_reason(xml, :reason, reason)
      end
    end
  end
end
