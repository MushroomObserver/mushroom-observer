# frozen_string_literal: true

# Validation of Query parameters.
class Query::ScopeModules::Validator < ActiveModel::Validator
  def initialize(options = {})
    super
    options[:class].attr_accessor(:validation_errors)
    # debugger
    # @parameter_declarations = options[:parameter_declarations]
    # @validation_errors = options[:validation_errors]
  end

  def validate(params)
    debugger
    params.validation_errors.blank?
  end
end
