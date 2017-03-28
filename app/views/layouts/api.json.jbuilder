json.version @api.version
json.run_date @start_time
if @api.user
  json.user @api.user.id
end
content = yield
unless content.blank?
  if @api.query
    json.query @api.query.query
    json.number_of_records @api.num_results
    json.number_of_pages @api.num_pages
    json.page_number @api.page_number
  end
  # json.results JSON.parse(content)
  json.results content
end
if @api.errors.length > 0
  json.errors @api.errors do |error|
    json.code    error.class.name
    json.details error.to_s
    json.fatal   error.fatal ? "true" : "false"
    json.trace   error.backtrace.join("\n") unless Rails.env == "production" or !error.backtrace
  end
end
@end_time = Time.now
json.run_time @end_time - @start_time
