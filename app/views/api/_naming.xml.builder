xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "naming"
) do
  xml_confidence_level(xml, :confidence, object.vote_cache)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  reasons = object.get_reasons.select(&:used?)
  if reasons.any?
    xml.reasons(:number => reasons.length) do
      for reason in reasons
        xml_naming_reason(xml, :reason, reason)
      end
    end
  end
  xml_detailed_object(xml, :name, object.name)
  if !detail
    xml_minimal_object(xml, :owner, User, object.user_id)
    xml_minimal_object(xml, :observation, Observation, object.observation_id)
  else
    xml_detailed_object(xml, :owner, object.user)
    xml_detailed_object(xml, :observation, object.observation)
    xml.votes(:number => object.votes.length) do
      for vote in object.votes
        xml_detailed_object(xml, :vote, vote)
      end
    end
  end
end
