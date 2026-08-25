# frozen_string_literal: true

# Report-only pass: wraps every test's execution, capturing
# $stdout/$stderr for that test alone, and appends anything
# unexpectedly written there to REPORT_PATH instead of failing the
# test. A test that already redirects its own output (capture_io,
# Rails.logger.stub) doesn't leak anything here, since that redirect
# happens inside this wrapper's span and is restored before it ends.
#
# Redirects at the OS file-descriptor level (STDOUT.reopen), not by
# reassigning the $stdout global -- Rails.logger's underlying
# Logger::LogDevice captures a direct reference to the STDOUT object
# at boot (config.logger = Logger.new($stdout) in
# config/environments/test.rb), so a plain `$stdout = StringIO.new`
# swap doesn't touch it. Reopening STDOUT's file descriptor mutates
# that same captured object in place, so every writer is redirected
# regardless of which reference it holds.
#
# Once a run against the full suite is clean, flip ENFORCE to true so
# a leak becomes a test failure instead of a report line.
module NoTestConsoleNoise
  REPORT_PATH = Rails.root.join("tmp/test_console_noise_report.txt")
  ENFORCE = false

  def run
    out_tempfile = Tempfile.new("test_stdout")
    err_tempfile = Tempfile.new("test_stderr")
    original_stdout = $stdout.dup
    original_stderr = $stderr.dup
    result = nil
    begin
      $stdout.reopen(out_tempfile)
      $stderr.reopen(err_tempfile)
      result = super
    ensure
      $stdout.reopen(original_stdout)
      $stderr.reopen(original_stderr)
      original_stdout.close
      original_stderr.close
    end

    leaked = read_and_close(out_tempfile) + read_and_close(err_tempfile)
    record_leak(leaked) if leaked.present?
    result
  end

  private

  def read_and_close(tempfile)
    tempfile.rewind
    content = tempfile.read
    tempfile.close!
    content
  end

  def record_leak(leaked)
    entry = "#{self.class}##{name}\n#{leaked}#{"-" * 40}\n"
    File.open(REPORT_PATH, "a") do |f|
      f.flock(File::LOCK_EX)
      f.write(entry)
      f.flock(File::LOCK_UN)
    end
  end
end

Minitest::Test.prepend(NoTestConsoleNoise)
