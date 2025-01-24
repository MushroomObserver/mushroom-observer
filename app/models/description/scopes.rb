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
    # scope searching note content, using a SearchParams phrase
    scope :search_content,
          ->(phrase) { search_columns(description_notes_columns, phrase) }
  end

  module ClassMethods
    # class methods here, `self` included
    def parent_class
      parent_type.camelize.constantize
    end

    # .coalesce("") is needed on each concatenated column here.
    def description_notes_columns
      fields = self::ALL_NOTE_FIELDS.dup
      starting = arel_table[fields.shift].coalesce("")
      fields.reduce(starting) do |result, field|
        result + arel_table[field].coalesce("")
      end
    end
  end
end
