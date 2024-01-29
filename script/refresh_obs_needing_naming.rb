#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path("../config/boot.rb", __dir__))
require(File.expand_path("../config/environment.rb", __dir__))
require(File.expand_path("../app/extensions/extensions.rb", __dir__))


# Use the original definition of `needs_id` to set the column values
def populate_observation_needs_naming_column
  Observation.with_name_above_genus.or(without_confident_name).
    update_all(needs_naming: true)
end

# All prior votes on an obs naming count as having "marked (obs) as reviewed"
# Make a hash of all votes, keyed by observation and user, set as 2
# Reset all those values to 1 if the key of an observation_view with `reviewed`
# matches the key of the working hash.
# All remaining hashes with a `2` value will need to set the corresponding
# `observation_view` with `reviewed: true`, or make a new OV

# For updating reviewed status, I would load ALL obs_id, user_id from votes, and create a hash keyed on obs and user whose value is 1.  Then go through all observation_views, and mark each obs/user pair from that table a 2.  Now you know you need to insert rows into observation_views for each entry that's still a 1.  That, too, can be done in bulk.  Do we every actually care if we accidentally marked something reviewed that shouldn't be?  Probably not.  That kinda takes care of both the initial population AND nightly job, doesn't it?

def update_observation_views_reviewed_column
  working_hash = {}
  # Because of anonymous voting, many votes have user_id: 0 and are useless for
  # setting `reviewed` status. Filter those out.
  # Store the updated_at as the value (in case we need a new OV)
  Vote.where.not(user_id: 0).
    select(:observation_id, :user_id, :updated_at).each do |v|
    working_hash[[v.observation_id, v.user_id]] = v.updated_at
  end

  ObservationView.where(reviewed: true).
    select(:observation_id, :user_id).each do |ov|
    if working_hash[[ov.observation_id, ov.user_id]].present?
      working_hash[[ov.observation_id, ov.user_id]] = 1
    end
  end

  # Remove where we've already got it reviewed.
  working_hash.reject { |_k, v| v == 1 }

  working_hash.each do |k, v|
    ov = ObservationView.find_by(observation_id: k[0], user_id: k[1])
    if ov
      ov.update(reviewed: 1)
    else
      ObservationView.create(
        { observation_id: k[0],
          user_id: k[1],
          last_viewed: v,
          reviewed: 1 }
      )
    end
  end
end
