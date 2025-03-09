# frozen_string_literal: true

module Description::Scopes
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do
    scope :is_default, lambda {
      joins(:name).where(parent_class[:description_id].not_eq(nil)).distinct
    }
    scope :is_not_default, lambda {
      joins(:name).where(parent_class[:description_id].eq(nil)).distinct
    }
    # scope searching notes content all fields, using a SearchParams phrase
    scope :content_has,
          ->(phrase) { search_columns(searchable_columns, phrase) }
    # alias used by advanced_search
    scope :search_content,
          ->(phrase) { content_has(phrase) }
  end

  module ClassMethods
    # class methods here, `self` included
    def parent_class
      parent_type.camelize.constantize
    end
  end
end
