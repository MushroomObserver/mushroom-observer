xml.results(:number => @api.result_ids.length) do
  if @api.detail == :none
    for result_id in @api.result_ids
      xml_minimal_object(xml, :result, @api.model, result_id)
    end
  else
    for result in @api.results
      xml_detailed_object(xml, :result, result, @api.detail == :high)
    end
  end
end
