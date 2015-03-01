#!/usr/bin/env ruby

app_root = File.expand_path("../..", __FILE__)
exec("#{app_root}/script/s3cp.rb --delete #{ARGV.join(' ')}")
