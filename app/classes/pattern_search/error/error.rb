# frozen_string_literal: true

class PatternSearch::Error < ::StandardError
  attr_accessor :args

  def initialize(args = {})
    super
    self.args = args
  end
end
