# frozen_string_literal: true

class BrakemanTest < ActiveSupport::TestCase
  require 'brakeman'

  test 'no brakeman errors or warnings' do
    result = Brakeman.run Rails.root.to_s
    assert_equal([], result.errors)
    assert_equal([], result.warnings)
  end
end
