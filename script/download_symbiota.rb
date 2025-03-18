#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative("../config/boot")
require_relative("../config/environment")
require_relative("../config/initializers/extensions")

def do_report(year, do_labels = false)
  warn("Doing #{year.inspect}...")
  query = Query.lookup(:Observation, date: year)
  report = Report::Symbiota.new(query: query).render
  report.sub!(/^[^\n]*\n/, "") unless do_labels
  puts(report)
  warn("  #{query.num_results} observations\n")
  sleep(60)
end

do_report(%w[1000 1999], :do_labels)
(2000..2019).each do |year|
  do_report([year.to_s, year.to_s])
end
exit(0)
