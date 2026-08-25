# frozen_string_literal: true

# Wraps every test's execution, capturing $stdout/$stderr for that
# test alone. A test that already redirects its own output
# (capture_io, Rails.logger.stub) doesn't leak anything here, since
# that redirect happens inside this wrapper's span and is restored
# before it ends. Anything else written there fails the test
# (ENFORCE = true) -- set false to log leaks to REPORT_PATH instead
# of failing, for an initial sweep against the full suite.
#
# Redirects at the OS file-descriptor level (STDOUT.reopen), not by
# reassigning the $stdout global -- Rails.logger's underlying
# Logger::LogDevice captures a direct reference to the STDOUT object
# at boot (config.logger = Logger.new($stdout) in
# config/environments/test.rb), so a plain `$stdout = StringIO.new`
# swap doesn't touch it. Reopening STDOUT's file descriptor mutates
# that same captured object in place, so every writer is redirected
# regardless of which reference it holds.
module NoTestConsoleNoise
  REPORT_PATH = Rails.root.join("tmp/test_console_noise_report.txt")
  ENFORCE = true

  def run
    # rubocop:disable Style/GlobalStdStream -- this hook redirects the
    # process's STDOUT/STDERR file descriptors, not the reassignable
    # $stdout/$stderr globals (see the class comment) -- autocorrecting
    # these to $stdout/$stderr defeats the point.
    out_tempfile = Tempfile.new("test_stdout")
    err_tempfile = Tempfile.new("test_stderr")
    original_stdout = STDOUT.dup
    original_stderr = STDERR.dup
    result = nil
    begin
      STDOUT.reopen(out_tempfile)
      STDERR.reopen(err_tempfile)
      result = super
    ensure
      STDOUT.reopen(original_stdout)
      STDERR.reopen(original_stderr)
      original_stdout.close
      original_stderr.close
    end
    # rubocop:enable Style/GlobalStdStream

    leaked = read_and_close(out_tempfile) + read_and_close(err_tempfile)
    handle_leak(result, leaked) if leaked.present?
    result
  end

  private

  def read_and_close(tempfile)
    tempfile.rewind
    content = tempfile.read
    tempfile.close!
    content
  end

  def handle_leak(result, leaked)
    message = "Unexpected console output during this test -- capture " \
              "it (Rails.logger.stub, capture_io, etc.) instead of " \
              "letting it print:\n\n#{leaked}"
    if ENFORCE
      fail_result(result, message)
    else
      record_leak(message)
    end
  end

  # flunk raises through Minitest::Assertions (included in every Test)
  # so the failure gets a proper backtrace; `super`'s Result.from(self)
  # already ran by the time this fires, so the failure has to go onto
  # that Result directly, not onto self.failures.
  def fail_result(result, message)
    flunk(message)
  rescue Minitest::Assertion => e
    result.failures << e
  end

  def record_leak(message)
    entry = "#{self.class}##{name}\n#{message}#{"-" * 40}\n"
    File.open(REPORT_PATH, "a") do |f|
      f.flock(File::LOCK_EX)
      f.write(entry)
      f.flock(File::LOCK_UN)
    end
  end
end

Minitest::Test.prepend(NoTestConsoleNoise)
