# frozen_string_literal: true

# Backs `Components::Form::PatternSearch` — the top-nav search bar's
# GET form that lets a user type a pattern and pick a target type
# (observations / names / locations / etc.). `SearchController#pattern`
# reads `params.dig(:pattern_search, :pattern)` and
# `params.dig(:pattern_search, :type)`; the FormObject's namespacing
# (`pattern_search[…]`) lines up with both reads.
class FormObject::PatternSearch < FormObject::Base
  attribute :pattern, :string
  attribute :type, :string
end
