require "test_helper"

# test MO extensions to Ruby's Object class
class ObjectExtensionsTest < UnitTestCase
  def test_stacktrace_removes_caller
    # Reflect on this test method's name (in case someone chooses to rename it).
    caller = __method__.to_s
    assert_not(_stacktrace.first.include?(caller),
               "Trace should start with #{caller}'s caller, not #{caller}")
  end

  def test_stacktrace_appends_executable
    assert(_stacktrace.last.end_with?($PROGRAM_NAME),
           "Trace should end with #{$PROGRAM_NAME}")
  end
end
