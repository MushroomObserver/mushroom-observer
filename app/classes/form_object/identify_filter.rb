# frozen_string_literal: true

# Form object for the identify observations filter form.
# Params namespaced as identify_filter[term], identify_filter[type],
# etc. -- matches Query::Observations' identify_filter query_attr
# directly, no controller-side param translation needed.
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
end
