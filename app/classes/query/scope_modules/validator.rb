# frozen_string_literal: true

# Validation of Query parameters.
class Query::ScopeModules::Validator < ActiveModel::Validator
  def initialize(options={})
    super
    # debugger
    # options[:class].attr_accessor(:params, :params_cache, :subqueries)
    # @parameter_declarations = options[:parameter_declarations]
    @validation_errors = options[:validation_errors]
  end

  def validate(_record)
    return false if @validation_errors

    true
  end
end
