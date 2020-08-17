#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path("../config/boot.rb", __dir__))
require(File.expand_path("../config/environment.rb", __dir__))
require(File.expand_path("../app/extensions/extensions.rb", __dir__))

def do_report(year, do_labels = false)
  warn("Doing #{year.inspect}...")
  query = Query.lookup(:Observation, :all, date: year)
  report = ObservationReport::Symbiota.new(query: query).render
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
