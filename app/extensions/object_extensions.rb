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
    begin
      raise
    rescue => e
      result = e.backtrace
      result.shift
      result.shift
      result.push "main: #{File.expand_path($0)}"
      result
    end
  end
end
