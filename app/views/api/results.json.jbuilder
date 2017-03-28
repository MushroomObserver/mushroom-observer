if @api.detail == :none
  json.array! @api.result_ids do |result_id|
    json.integer! result_id
  end
else
  json.array! @api.results do |result|
    json_detailed_object(json, result, @api.detail == :high)
  end
end
