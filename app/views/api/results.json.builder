if @api.detail == :none
  json.results @api.result_ids do |result_id|
    json.id result_id
  end
else
  json.results @api.results do |result|
    json_detailed_object(json, result, @api.detail == :high)
  end
end
