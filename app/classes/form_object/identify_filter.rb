# frozen_string_literal: true

# Form object for the identify observations filter form.
# Params namespaced as filter[term], filter[type], etc.
class FormObject::IdentifyFilter < FormObject::Base
  VALID_TYPES = %w[clade region].freeze

  attribute :term, :string
  attribute :term_id, :string
  attribute :type, :string, default: "clade"

  # Coerce unknown / nil type values to "clade" so the form select
  # always has a valid option to select and downstream callers can
  # trust the value.
  def type=(value)
    super(VALID_TYPES.include?(value) ? value : "clade")
  end

  def self.model_name
    ActiveModel::Name.new(self, nil, "Filter")
  end
end
