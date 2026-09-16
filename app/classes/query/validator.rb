# frozen_string_literal: true

##############################################################################
#
#  :class: Validator
#
#  Validation of Query parameters.
#
class Query::Validator < ActiveModel::Validator
  def initialize(options = {})
    super
    options[:class].attr_accessor(:validation_errors)
  end

  def validate(params)
    return if params.validation_errors.blank?

    params.validation_errors.each do |tag, args|
      params.errors.add(:base, tag, **(args || {}))
    end
  end
end
