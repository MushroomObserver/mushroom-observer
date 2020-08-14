# frozen_string_literal: true

require("test_helper")

class ScriptTest < UnitTestCase
  def script_file(cmd)
    "#{::Rails.root}/script/#{cmd}"
  end

  ##############################################################################

  test "autoreply" do
    sender = "test@email.com"
    subject = "RE: do not reply"
    header = "To: blah\nFrom: blah\nSubject: blah"
    body = "Some sort of comment.\nObject notification."
    tempfile = Tempfile.new("test").path
    script = script_file("autoreply")
    env = { "SENDER" => sender }
    cmd = "echo \"#{header}\n\n#{body}\" | #{script} \"#{subject}\" " \
          "> #{tempfile}"
    assert system(env, cmd)
    expect = <<-EMAIL.unindent
      To: #{sender}
      Subject: #{subject}

      Please do not reply to this email.

      ----------------------------------------

      #{body}
    EMAIL
    actual = File.read(tempfile)
    assert_equal(expect, actual)
  end

  test "jpegsize" do
    script = script_file("jpegsize")
    [
      ["Coprinus_comatus.jpg", 2288, 2168],
      ["perf.jpg", 4288, 2848],
      ["sticky.jpg", 407, 500]
    ].each do |file, width, height|
      result = `#{script} #{::Rails.root}/test/images/#{file}`.chomp
      assert_equal("#{width} #{height}", result)
    end
  end

  test "lookup_user" do
    script = script_file("lookup_user")
    tempfile = Tempfile.new("test").path
    cmd = "#{script} dick > #{tempfile}"
    assert system(cmd)
    expect =
      "id login name email verified last_use\n" \
      "#{users(:dick).id} dick Tricky Dick dick@collectivesource.com " \
      "2006-03-02 21:14:00 NULL\n"
    actual = File.read(tempfile).gsub(/ +/, " ")
    assert_equal(expect, actual)
  end

  test "make_eol_xml" do
    script = script_file("make_eol_xml")
    dest_file = Tempfile.new("test").path
    stdout_file = Tempfile.new("test").path
    assert !File.exist?(dest_file) || File.size(dest_file).zero?
    cmd = "#{script} #{dest_file} > #{stdout_file}"

    script_succeeded = system(cmd)

    assert script_succeeded, "Script failed."
    assert File.size(dest_file).positive?,
           "#{dest_file} should have content but is empty."
    assert_equal("", File.read(stdout_file),
                 "#{stdout_file} should be empty, but has content")
    # In test mode, the script just grabs first observation from api
    # (or mocks grabbing the first observation from api).
    # We don't care about testing name/eol, we just want to test that
    # the script can successfully wget any page from the server!
    assert File.read(dest_file).match(/<results number="1">/)
    # system("cp #{dest_file} x.xml")
  end

  test "monitor_top" do
    script = script_file("monitor_top")
    tempfile = Tempfile.new("test").path
    logfile = "#{::Rails.root}/log/top.log"
    old_size = begin
                 File.size(logfile)
               rescue StandardError
                 0
               end
    cmd = "#{script} 2>&1 > #{tempfile}"
    status = system(cmd)
    errors = File.read(tempfile)
    assert(status, "Something went wrong with #{script}:\n#{errors}")
    assert_equal("", File.read(tempfile))
    new_size = File.size(logfile)
    assert_operator(new_size, :>, old_size)
  end

  test "parse_log" do
    script = script_file("parse_log")
    tempfile = Tempfile.new("test").path
    cmd = "#{script} 2>&1 > #{tempfile}"
    status = system(cmd)
    errors = File.read(tempfile)
    assert status, "Something went wrong with #{script}:\n#{errors}"
  end

  test "refresh_name_lister_cache" do
    script = script_file("refresh_name_lister_cache")
    tempfile = Tempfile.new("test").path
    output_file = MO.name_lister_cache_file
    FileUtils.rm(output_file) if File.exist?(output_file)
    cmd = "#{script} 2>&1 > #{tempfile}"
    status = system(cmd)
    errors = File.read(tempfile)
    assert(status && errors.blank?,
           "Something went wrong with #{script}:\n#{errors}")
    assert(File.exist?(output_file),
           "#{script} failed to write #{output_file}")

    output = File.read(output_file)
    fixture = "#{::Rails.root}/test/reports/name_list_data.js"
    if sql_collates_accents?
      assert_string_equal_file(output, fixture)
    else
      expect = File.read(fixture)
      assert_equal(expect.tr("ü", "u"), output.tr("ü", "u"),
                   "File #{output} is wrong.")
    end
  end
end
