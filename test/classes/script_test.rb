# frozen_string_literal: true

require("test_helper")

class ScriptTest < UnitTestCase
  include GeneralExtensions

  def script_file(cmd)
    Rails.root.join("script/#{cmd}").to_s
  end

  # Environment for running scripts with worker-specific database config
  def script_env
    worker_num = database_worker_number
    if worker_num
      config_file = Rails.root.join("config/mysql-test-#{worker_num}.cnf")
      db_name = "mo_test-#{worker_num}"
      {
        "MO_MYSQL_CONFIG" => config_file.to_s,
        "MO_TEST_DATABASE" => db_name,
        "RAILS_ENV" => "test"
      }
    else
      { "RAILS_ENV" => "test" }
    end
  end

  ##############################################################################

  def test_autoreply
    sender = "test@email.com"
    subject = "RE: do not reply"
    header = "To: blah\nFrom: blah\nSubject: blah"
    body = "Some sort of comment.\nObject notification."
    tmpfile = Tempfile.new("test")
    script = script_file("autoreply")
    env = script_env.merge("SENDER" => sender)
    cmd = "echo \"#{header}\n\n#{body}\" | #{script} \"#{subject}\" " \
          "> #{tmpfile.path}"
    assert(system(env, cmd))
    expect = <<-EMAIL.unindent
      To: #{sender}
      Subject: #{subject}

      Please do not reply to this email.

      ----------------------------------------

      #{body}
    EMAIL
    actual = File.read(tmpfile.path)
    assert_equal(expect, actual)
  end

  # Now uses gem, no need to test here
  # test "jpegsize" do
  #   script = script_file("jpegsize")
  #   [
  #     ["Coprinus_comatus.jpg", 2288, 2168],
  #     ["perf.jpg", 4288, 2848],
  #     ["sticky.jpg", 407, 500]
  #   ].each do |file, width, height|
  #     result = `#{script} #{::Rails.root}/test/images/#{file}`.chomp
  #     assert_equal("#{width} #{height}", result)
  #   end
  # end

  def test_lookup_user
    script = script_file("lookup_user")
    tmpfile = Tempfile.new("test")
    cmd = "#{script} dick > #{tmpfile.path}"
    assert(system(script_env, cmd))
    expect =
      "id login name email verified last_use\n" \
      "#{users(:dick).id} dick Tricky Dick dick@collectivesource.com " \
      "2006-03-02 21:14:00 NULL\n"
    actual = File.read(tmpfile.path).squeeze(" ")
    assert_equal(expect, actual)
  end

  def test_make_eol_xml
    script = script_file("make_eol_xml")
    dest_tmpfile = Tempfile.new("test")
    stdout_tmpfile = Tempfile.new("test")
    assert(!File.exist?(dest_tmpfile.path) || File.empty?(dest_tmpfile.path))
    cmd = "#{script} #{dest_tmpfile.path} > #{stdout_tmpfile.path}"

    script_succeeded = system(script_env, cmd)

    assert(script_succeeded, "Script failed.")
    assert(File.size(dest_tmpfile.path).positive?,
           "#{dest_tmpfile.path} should have content but is empty.")
    assert_equal("", File.read(stdout_tmpfile.path),
                 "#{stdout_tmpfile.path} should be empty, but has content")
    # In test mode, the script just grabs first observation from api
    # (or mocks grabbing the first observation from api).
    # We don't care about testing name/eol, we just want to test that
    # the script can successfully wget any page from the server!
    assert(File.read(dest_tmpfile.path).include?('<results number="1">'))
    # system("cp #{dest_tmpfile.path} x.xml")
  end

  def test_parse_log
    script = script_file("parse_log")
    tmpfile = Tempfile.new("test")
    cmd = "#{script} &>#{tmpfile.path}"
    status = system(script_env, cmd)
    errors = File.read(tmpfile.path)
    assert(status, "Something went wrong with #{script}:\n#{errors}")
  end

  # A Solid Queue worker logs no "Started" lines: each job is a separate
  # bundle, and a bundle holding several of the strings prints once.
  def test_extract_log_prints_each_job_once
    output = run_extract_log(<<~LOG, "first failure\nsecond failure\n")
      I, [2026-10-28T17:00:00.000000 #42]  INFO -- : Performing MailJob (Job ID: a) from SolidQueue(default)
      E, [2026-10-28T17:00:01.000000 #42] ERROR -- : first failure
      E, [2026-10-28T17:00:02.000000 #42] ERROR -- : second failure
      I, [2026-10-28T17:00:03.000000 #42]  INFO -- : Performing MailJob (Job ID: b) from SolidQueue(default)
      I, [2026-10-28T17:00:04.000000 #42]  INFO -- : unrelated job line
    LOG

    assert_equal(1, output.scan("first failure").size,
                 "A bundle should print once, not once per string it holds")
    assert_not_includes(output, "unrelated job line",
                        "The next job should start a new bundle")
  end

  def test_extract_log_truncates_output
    jobs = Array.new(3000) do |i|
      "I, [2026-10-28T17:00:00.000000 #42]  INFO -- : Performing MailJob " \
        "(Job ID: #{i}) from SolidQueue(default)\n" \
        "E, [2026-10-28T17:00:01.000000 #42] ERROR -- : boom\n#{"x" * 500}\n"
    end
    output = run_extract_log(jobs.join, "boom\n")

    assert_operator(output.bytesize, :<, 1_100_000)
    assert_includes(output.lines.last, "Output truncated")
  end

  def run_extract_log(log_text, input)
    log = Tempfile.new("extract_log")
    log.write(log_text)
    log.close
    output, = Open3.capture2({ "EXTRACT_LOG_FILE" => log.path },
                             script_file("extract_log"), stdin_data: input)
    output
  ensure
    log&.unlink
  end
end
