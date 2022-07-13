# frozen_string_literal: true

# Scopes for collecting objects created (or updated) on, before, after or
# between a given "%Y-%m-%d" string(s).
# Include in a model to have them available:
#
# include ScopesForTimestamps
#
# Examples: Observation.created_between("2006-09-01", "2012-09-01")
#           Name.updated_after("2016-12-01")

module ScopesForTimestamps
  extend ActiveSupport::Concern

  included do
    scope :created_on, lambda { |ymd_string|
      where(arel_table[:created_at].format("%Y-%m-%d") == ymd_string)
    }
    scope :created_after, lambda { |ymd_string|
      where(arel_table[:created_at].format("%Y-%m-%d") >= ymd_string)
    }
    scope :created_before, lambda { |ymd_string|
      where(arel_table[:created_at].format("%Y-%m-%d") <= ymd_string)
    }
    scope :created_between, lambda { |earliest, latest|
      where(arel_table[:created_at].format("%Y-%m-%d") >= earliest).
        where(arel_table[:created_at].format("%Y-%m-%d") <= latest)
    }
    scope :updated_on, lambda { |ymd_string|
      where(arel_table[:updated_at].format("%Y-%m-%d") == ymd_string)
    }
    scope :updated_after, lambda { |ymd_string|
      where(arel_table[:updated_at].format("%Y-%m-%d") >= ymd_string)
    }
    scope :updated_before, lambda { |ymd_string|
      where(arel_table[:updated_at].format("%Y-%m-%d") <= ymd_string)
    }
    scope :updated_between, lambda { |earliest, latest|
      where(arel_table[:updated_at].format("%Y-%m-%d") >= earliest).
        where(arel_table[:updated_at].format("%Y-%m-%d") <= latest)
    }
  end

  class_methods do
  end
end
