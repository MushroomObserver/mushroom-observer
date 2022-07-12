# frozen_string_literal: true

# Observation.created_at("2005-03-04").to_sql
module CreatedUpdatedScopes
  extend ActiveSupport::Concern

  included do
    scope :created_at, lambda { |ymd_string|
      where(arel_table[:created_at].format("%Y-%m-%d") == ymd_string)
    }
    scope :created_after, lambda { |ymd_string|
      where(arel_table[:created_at].format("%Y-%m-%d") >= ymd_string)
    }
    scope :created_before, lambda { |ymd_string|
      where(arel_table[:created_at].format("%Y-%m-%d") <= ymd_string)
    }
    scope :updated_at, lambda { |ymd_string|
      where(arel_table[:updated_at].format("%Y-%m-%d") == ymd_string)
    }
    scope :updated_after, lambda { |ymd_string|
      where(arel_table[:updated_at].format("%Y-%m-%d") >= ymd_string)
    }
    scope :updated_before, lambda { |ymd_string|
      where(arel_table[:updated_at].format("%Y-%m-%d") <= ymd_string)
    }
  end

  class_methods do
  end
end
