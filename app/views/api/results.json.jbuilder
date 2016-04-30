if @api.detail == :none
  json.array! @api.result_ids do |result_id|
    json.id result_id
  end
else
  json.array! @api.results do |result|
    json.id result_id
    # json_detailed_object(json, result, @api.detail == :high)
  end
end
