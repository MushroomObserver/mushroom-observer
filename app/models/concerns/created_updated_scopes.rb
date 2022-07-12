# frozen_string_literal: true

# Observation.created_at("2005-03-04").to_sql
module CreatedUpdatedScopes
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
      where(arel_table[:created_at].format("%Y-%m-%d") == earliest).
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
