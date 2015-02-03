# encoding: utf-8
require 'test_helper'

class ScriptTest < UnitTestCase
  def script_file(cmd)
    "#{::Rails.root}/script/#{cmd}"
  end

################################################################################

  test "autoreply" do
    sender = "test@email.com"
    subject = "RE: do not reply"
    header = "To: blah\nFrom: blah\nSubject: blah"
    body = "Some sort of comment.\nObject notification."
    tempfile = Tempfile.new("test").path
    script = script_file("autoreply")
    env = { "SENDER" => sender }
    cmd = "echo \"#{header}\n\n#{body}\" | #{script} \"#{subject}\" > #{tempfile}"
    assert_block { system(env, cmd) }
    expect = <<-END.unindent
      To: #{sender}
      Subject: #{subject}

      Please do not reply to this email.

      ----------------------------------------

      #{body}
    END
    actual = File.read(tempfile)
    assert_equal(expect, actual)
  end

  test "jpegsize" do
    script = script_file("jpegsize")
    [
      [ "Coprinus_comatus.jpg", 2288, 2168 ],
      [ "perf.jpg", 4288, 2848 ],
      [ "sticky.jpg", 407, 500 ]
    ].each do |file, width, height|
      result = `#{script} #{::Rails.root}/test/images/#{file}`.chomp
      assert_equal("#{width} #{height}", result)
    end
  end

  test "lookup_user" do
    script = script_file("lookup_user")
    tempfile = Tempfile.new("test").path
    cmd = "#{script} dick > #{tempfile}"
    assert_block { system(cmd) }
    expect = "id login name email verified last_use\n" +
             "4 dick Tricky Dick dick@collectivesource.com 2006-03-02 21:14:00 NULL\n"
    actual = File.read(tempfile).gsub(/ +/, ' ')
    assert_equal(expect, actual)
  end

  test "make_eol_xml" do
    script = script_file("make_eol_xml")
    dest_file = Tempfile.new("test").path
    stdout_file = Tempfile.new("test").path
    cmd = "#{script} #{dest_file} > #{stdout_file}"
    assert_block { !File.exist?(dest_file) || File.size(dest_file) == 0 }
    assert_block { system(cmd) }
    assert_block { File.size(dest_file) > 0 }
    assert_equal("", File.read(stdout_file))

    # In test mode, the script just grabs first observation from api.
    # We don't care about testing name/eol, we just want to test that
    # the script can successfully wget any page from the server!
    assert_block { File.read(dest_file).match(/<results number="1">/) }
    # system("cp #{dest_file} x.xml")
  end

  test "monitor_top" do
    script = script_file("monitor_top")
    tempfile = Tempfile.new("test").path
    logfile = "#{::Rails.root}/log/top.log"
    old_size = File.size(logfile) rescue 0
    cmd = "#{script} 2>&1 > #{tempfile}"
    status = system(cmd)
    errors = File.read(tempfile)
    assert_block("Something went wrong with #{script}:\n#{errors}") { status }
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
    assert_block("Something went wrong with #{script}:\n#{errors}") { status }
  end

  # Takes way too long, bad for the live server(!) and unreliable.
  # Oh, and no one uses it anymore, anyway.  So there.
  # test "perf_monitor" do
  #   begin
  #     script = script_file("perf_monitor")
  #     tempfile = Tempfile.new("test").path
  #     tempdir = "#{tempfile}.dir"
  #     site = "mushroomobserver.org"
  #     image = "#{::Rails.root}/public/assets/eye.png"
  #     cmd = "#{script} #{site} #{image} #{tempdir} 1 2>&1 > #{tempfile}"
  #     status = system(cmd)
  #     errors = File.read(tempfile)
  #     assert_block("Something went wrong with #{script}:\n#{errors}") { status }
  #     logfile = "#{tempdir}/perf.log"
  #     assert_block { File.exist?(logfile) && File.size(logfile) > 0 }
  #     lines = File.readlines(logfile)
  #     assert_equal(5, lines.length)
  #     assert_block("There were errors in perf.log:\n#{lines.join("\n")}") do
  #       lines.none? {|line| line.match(/ERROR/)}
  #     end
  #   ensure
  #     system("rm -rf #{tempdir}") if File.directory?(tempdir)
  #   end
  # end

  test "refresh_name_lister_cache" do
    script = script_file("refresh_name_lister_cache")
    tempfile = Tempfile.new("test").path
    output_file = MO.name_lister_cache_file
    FileUtils.rm(output_file) if File.exist?(output_file)
    cmd = "#{script} 2>&1 > #{tempfile}"
    status = system(cmd)
    errors = File.read(tempfile)
    assert_block("Something went wrong with #{script}:\n#{errors}") { status && errors.blank? }
    output = File.read(output_file)
    fixture = "#{::Rails.root}/test/reports/name_list_data.js"
    assert_string_equal_file(output, fixture)
  end
end
