# frozen_string_literal: true

# Form object for the identify observations filter form.
# Params namespaced as filter[term], filter[type], etc.
class FormObject::IdentifyFilter < FormObject::Base
  attribute :term, :string
  attribute :term_id, :string
  attribute :type, :string, default: "clade"

  def self.model_name
    ActiveModel::Name.new(self, nil, "Filter")
  end
end
