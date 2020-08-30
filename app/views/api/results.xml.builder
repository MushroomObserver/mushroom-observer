xml.instruct!(:xml, version: "1.0")
xml.response(xmlns: "#{MO.http_domain}/response.xsd") do
  xml_string(xml, :version, @api.version)
  xml_datetime(xml, :run_date, @start_time)
  if @api.user
    xml_minimal_object(xml, :user, User, @api.user.id)
  end

  unless @api.errors.any?(&:fatal)
    if @api.query
      xml_sql_string(xml, :query, @api.query.query.gsub(/\s*\n\s*/, " ").strip)
      xml_integer(xml, :number_of_records, @api.num_results)
      xml_integer(xml, :number_of_pages, @api.num_pages)
      xml_integer(xml, :page_number, @api.page_number)
    end

    xml.results(number: @api.result_ids.length) do
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
  end

  if @api.errors.length > 0
    xml.errors(number: @api.errors.length) do
      i = 1
      for error in @api.errors
        xml.error(id: i) do
          xml.code    error.class.name
          xml.details error.to_s
          xml.fatal   error.fatal ? "true" : "false"
          unless Rails.env == "production" || !error.backtrace
            xml.trace   error.backtrace.join("\n")
          end
        end
        i += 1
      end
    end
  end

  @end_time = Time.zone.now
  xml_ellapsed_time(xml, :run_time, @end_time - @start_time)
end
