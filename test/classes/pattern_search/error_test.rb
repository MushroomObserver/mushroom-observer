# frozen_string_literal: true

require("test_helper")

# Exercises every PatternSearch error class: builds each with a superset of
# the args any #to_s reads and asserts it renders. The parser raises these on
# bad search input, but the suite rarely renders each, so their #to_s bodies
# sit uncovered. This also validates the error->translation contract (a
# missing en.txt key surfaces via the missing-translation teardown).
# Enumerating subclasses keeps the coverage complete as errors are added.
class PatternSearch::ErrorTest < UnitTestCase
  def setup
    User.current = users(:rolf)
  end

  def test_all_errors_render
    error_classes.each do |klass|
      error = klass.new(universal_args)

      assert_kind_of(String, error.to_s, "#{klass}#to_s")
      assert_not_empty(error.to_s, "#{klass}#to_s")
    end
  end

  def test_interpolation
    error = PatternSearch::BadBooleanError.new(var: "confirmed", val: "maybe")

    assert_includes(error.to_s, "confirmed")
  end

  private

  # A superset of every key read across the #to_s methods. `term` is an
  # object because BadTermError reads `args[:term].var`.
  def universal_args
    { var: "name", val: "xyz", min: 1, max: 9, string: "bad", str: "bad",
      type: :name, help: "help", term: Struct.new(:var).new("name") }
  end

  def error_classes
    Rails.application.eager_load!
    ObjectSpace.each_object(Class).select { |c| c < PatternSearch::Error }.uniq
  end
end
