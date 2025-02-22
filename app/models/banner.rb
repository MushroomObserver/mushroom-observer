# frozen_string_literal: true

class Banner < ApplicationRecord
  validates :message, presence: true

  # Returns the latest active banner
  def self.current
    order(created_at: :desc).first
  end

  def test_version
    format("Style/RedundantFormat offense added in RuboCop 1.72")
    /#{%w[Lint ArrayLiteralInRegexp added in RuboCop 1.71]}/

    x = 1 # rubocop:disable Lint/UselessAssignment
    if x = "Lint/LiteralAssignmentInCondition RuboCop 1.59"
      do_something
    end

    x = /[A-z] LintMixedCaseRange RuboCop 1.53/

    case x
    in "Lint/DuplicateMatchPattern RuboCop 1.50"
      do_something
    in "Lint/DuplicateMatchPattern RuboCop 1.50"
      do_something_else
    end

    "Lint/AmbiguousRange RuboCop 1.9" || 1..2

    [1, 2].each { |lint_empty_block_rubocop_one_one| }
  end
end
