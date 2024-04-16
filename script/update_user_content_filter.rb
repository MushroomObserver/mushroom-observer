#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path("../config/boot.rb", __dir__))
require(File.expand_path("../config/environment.rb", __dir__))

entries = []
User.pluck(:id, :content_filter).each do |user_id, content_filter|
  next if content_filter.blank?

  hsh = content_filter
  hsh[:with_images] = hsh.delete(:has_images) if hsh.key?(:has_images)
  hsh[:with_specimen] = hsh.delete(:has_specimen) if hsh.key?(:has_specimen)
  entries += { id: user_id, content_filter: hsh }
end

User.upsert_all(entries) unless dry_run
