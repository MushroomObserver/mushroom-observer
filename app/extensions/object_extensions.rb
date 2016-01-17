# encoding: utf-8
#
#  = Extensions to Object
#
#  == Instance Methods
#
#  _stacktrace::  Returns stacktrace; useful for debugging.
#
################################################################################

class Object
  # Handy debug routine that returns the stacktrace starting with whomever
  # called the caller, and winding up at the executable program's name.
  def _stacktrace
    fail
  rescue => e
    result = e.backtrace
    result.shift
    result.shift
    result.push "main: #{File.expand_path($PROGRAM_NAME)}"
    result
  end
end
