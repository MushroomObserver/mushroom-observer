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
end
