# frozen_string_literal: true

#
#  = Extensions to Object
#
#  == Instance Methods
#
#  _stacktrace::  Returns stacktrace; useful for debugging.
#
class Object
  # Handy debug routine that returns the stacktrace starting with whomever
  # called the caller, and winding up at the executable program's name.
  def _stacktrace
    result = caller(2)
    result.push("main: #{File.expand_path($PROGRAM_NAME)}")
  end

  # More convenient check for multiple `is_a?(klass)`. Using *klasses/flatten
  # allows this to accept both comma separated params as well as an Array.
  # Shut up Rubocop. This is the most idiomatic method name in this context.
  # rubocop:disable Naming/PredicatePrefix
  def is_any?(*klasses)
    klasses.flatten.any? do |klass|
      is_a?(klass)
    end
  end
  # rubocop:enable Naming/PredicatePrefix
end
