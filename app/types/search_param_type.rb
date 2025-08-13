# frozen_string_literal: true

# MO Custom attribute type for all Search subclass attributes (parameters).
# The arg `:input` describes what kind of input it should have in a form.
# `:validates` is an optional arg describing an autocompleter type.
# `:nested_under` is for params that get nested under another param.
# nested params are not permitted to be sent directly as query params.
#
# re: custom attribute types - https://stackoverflow.com/a/79417688/3357635
#                              https://stackoverflow.com/a/78668203/3357635
#
class SearchParamType < ActiveModel::Type::Value
  attr_reader :input, :autocompletes, :nested_under

  # Add our custom args to the default args.
  def initialize(input: nil, validates: nil, nested_under: nil)
    @input = input
    @validates = validates
    @nested_under = nested_under
    super()
  end

  # This is required and used if registering the type instead of just passing
  # the class (registered in config/initializers/active_model_types.rb)
  def type = :search_param
end
