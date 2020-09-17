json.version @api.version
json.run_date @start_time.utc
json.user @api.user.id if @api.user

unless @api.errors.any?(&:fatal)
  if @api.query
    json.query @api.query.query.gsub(/\s*\n\s*/, " ").strip
    json.number_of_records @api.num_results
    json.number_of_pages @api.num_pages
    json.page_number @api.page_number
  end

  if @api.detail == :none
    json.results @api.result_ids
  else
    json.results @api.results.map do |result|
      json_detailed_object(json, result, @api.detail == :high)
    end
  end
end

unless @api.errors.empty?
  json.errors @api.errors do |error|
    json.code    error.class.name
    json.details error.to_s
    json.fatal   error.fatal ? "true" : "false"
    if Rails.env != "production" && error.backtrace
      json.trace error.backtrace.join("\n")
    end
  end
end

@end_time = Time.zone.now
json.run_time @end_time - @start_time
