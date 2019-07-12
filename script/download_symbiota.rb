#!/usr/bin/env ruby

require File.expand_path("../config/boot.rb", __dir__)
require File.expand_path("../config/environment.rb", __dir__)
require File.expand_path("../app/extensions/extensions.rb", __dir__)

def do_report(year, do_labels = false)
  $stderr.puts("Doing #{year.inspect}...")
  query = Query.lookup(:Observation, :all, date: year)
  report = ObservationReport::Symbiota.new(query: query).render
  report.sub!(/^[^\n]*\n/, "") unless do_labels
  puts report
  $stderr.puts("  #{query.num_results} observations\n")
end

do_report("2010-01-01", :do_labels)
do_report("2010-01-02")

# do_report(["1000", "1999"], :do_labels)
# (2000..2019).each do |year|
#   do_report(year.to_s)
# end
exit 0
