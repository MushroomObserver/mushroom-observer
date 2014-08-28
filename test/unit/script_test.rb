# encoding: utf-8
require 'test_helper'

class ScriptTest < UnitTestCase
  DATABASE_CONFIG = YAML::load(IO.read("#{::Rails.root}/config/database.yml"))['test']

  def script_file(cmd)
    "#{::Rails.root}/script/#{cmd}"
  end

  def teardown
    # Need to reset any possible changes to database scripts might make because
    # they are external to the ActiveRecord test transanction which normally
    # rolls back any changes which occur inside a given test.
    user = DATABASE_CONFIG['username']
    pass = DATABASE_CONFIG['password']
    db   = DATABASE_CONFIG['database']
    cmd = "UPDATE images SET width=1000, height=1000, transferred=false WHERE id=1"
    system("mysql -u #{user} -p#{pass} #{db} -e '#{cmd}'")
  end

################################################################################

#   test "autoreply" do
#     sender = "test@email.com"
#     subject = "RE: do not reply"
#     header = "To: blah\nFrom: blah\nSubject: blah"
#     body = "Some sort of comment.\nObject notification."
#     tempfile = Tempfile.new("test").path
#     script = script_file("autoreply")
#     env = { "SENDER" => sender }
#     cmd = "echo \"#{header}\n\n#{body}\" | #{script} \"#{subject}\" > #{tempfile}"
#     assert_block { system(env, cmd) }
#     expect = <<-END.unindent
#       To: #{sender}
#       Subject: #{subject}
# 
#       Please do not reply to this email.
# 
#       ----------------------------------------
# 
#       #{body}
#     END
#     actual = File.read(tempfile)
#     assert_equal(expect, actual)
#   end
# 
#   test "jpegsize" do
#     script = script_file("jpegsize")
#     [
#       [ "Coprinus_comatus.jpg", 2288, 2168 ],
#       [ "perf.jpg", 4288, 2848 ],
#       [ "sticky.jpg", 407, 500 ]
#     ].each do |file, width, height|
#       result = `#{script} #{::Rails.root}/test/images/#{file}`.chomp
#       assert_equal("#{width} #{height}", result)
#     end
#   end
# 
#   test "lookup_user" do
#     script = script_file("lookup_user")
#     tempfile = Tempfile.new("test").path
#     cmd = "#{script} dick > #{tempfile}"
#     assert_block { system(cmd) }
#     expect = "id login name email verified last_use\n" +
#              "4 dick Tricky Dick dick@collectivesource.com 2006-03-02 21:14:00 NULL\n"
#     actual = File.read(tempfile).gsub(/ +/, ' ')
#     assert_equal(expect, actual)
#   end
# 
#   test "make_eol_xml" do
#     script = script_file("make_eol_xml")
#     dest_file = Tempfile.new("test").path
#     stdout_file = Tempfile.new("test").path
#     cmd = "#{script} #{dest_file} > #{stdout_file}"
#     assert_block { File.size(dest_file) == 0 }
#     assert_block { system(cmd) }
#     assert_block { File.size(dest_file) > 0 }
#     assert_equal("", File.read(stdout_file))
# 
#     # In test mode, the script just grabs first observation from api.
#     # We don't care about testing name/eol, we just want to test that
#     # the script can successfully wget any page from the server!
#     assert_block { File.read(dest_file).match(/<results number="1">/) }
#     # system("cp #{dest_file} x.xml")
#   end
# 
#   test "monitor_top" do
#     script = script_file("monitor_top")
#     tempfile = Tempfile.new("test").path
#     logfile = "#{::Rails.root}/log/top.log"
#     old_size = File.size(logfile) rescue 0
#     cmd = "#{script} 2>&1 > #{tempfile}"
#     status = system(cmd)
#     errors = File.read(tempfile)
#     assert_block("Something went wrong with #{script}:\n#{errors}") { status }
#     assert_equal("", File.read(tempfile))
#     new_size = File.size(logfile)
#     assert_operator(new_size, :>, old_size)
#   end
# 
#   test "parse_log" do
#     script = script_file("parse_log")
#     tempfile = Tempfile.new("test").path
#     cmd = "#{script} 2>&1 > #{tempfile}"
#     status = system(cmd)
#     errors = File.read(tempfile)
#     assert_block("Something went wrong with #{script}:\n#{errors}") { status }
#   end
# 
#   test "perf_monitor" do
#     begin
#       script = script_file("perf_monitor")
#       tempfile = Tempfile.new("test").path
#       tempdir = "#{tempfile}.dir"
#       site = "mushroomobserver.org"
#       image = "#{::Rails.root}/public/assets/eye.png"
#       cmd = "#{script} #{site} #{image} #{tempdir} 1 2>&1 > #{tempfile}"
#       status = system(cmd)
#       errors = File.read(tempfile)
#       assert_block("Something went wrong with #{script}:\n#{errors}") { status }
#       logfile = "#{tempdir}/perf.log"
#       assert_block { File.exist?(logfile) && File.size(logfile) > 0 }
#       lines = File.readlines(logfile)
#       assert_equal(5, lines.length)
#       assert_block("There were errors in perf.log:\n#{lines.join("\n")}") do
#         lines.none? {|line| line.match(/ERROR/)}
#       end
#     ensure
#       system("rm -rf #{tempdir}") if File.directory?(tempdir)
#     end
#   end
# 
#   test "process_image" do
#     script = script_file("process_image")
#     tempfile = Tempfile.new("test").path
#     img_root = MO.local_image_files
#     remote_root = "#{::Rails::root}/tmp/image_server"
#     original_image = "#{::Rails.root}/test/images/pleopsidium.tiff"
#     FileUtils.cp(original_image, "#{img_root}/orig/1.tiff")
#     system("rm -rf #{remote_root}*")
#     # Can't do this, since in unit tests ActiveRecord wraps all work on the
#     # database in a transaction.  Soon as you look at the database it becomes
#     # immune to external changes for the rest of the test.  So we need to be
#     # careful not to even peek at the database until we've run the script.
#     # img = Image.find(1)
#     # assert_equal(1000, img.width)
#     # assert_equal(1000, img.height)
#     # assert_equal(false, img.transferred)
#     cmd = "#{script} 1 tiff 1 2>&1 > #{tempfile}"
#     status = system(cmd)
#     errors = File.read(tempfile)
#     assert_block("Something went wrong with #{script}:\n#{errors}") { status && errors.blank? }
#     File.open(tempfile, "w") do |file|
#       file.puts "#{img_root}/orig/1.jpg"
#       file.puts "#{img_root}/1280/1.jpg"
#       file.puts "#{img_root}/960/1.jpg"
#       file.puts "#{img_root}/640/1.jpg"
#       file.puts "#{img_root}/320/1.jpg"
#       file.puts "#{img_root}/thumb/1.jpg"
#     end
#     sizes = File.readlines("| #{script_file('jpegsize')} -f #{tempfile}").map do |line|
#       line[img_root.length+1..-1].chomp
#     end
#     assert_equal("orig/1.jpg: 2560 1920", sizes[0], "full-size image is wrong size")
#     assert_equal("1280/1.jpg: 1280 960", sizes[1], "huge-size image is wrong size")
#     assert_equal("960/1.jpg: 960 720", sizes[2], "large-size image is wrong size")
#     assert_equal("640/1.jpg: 640 480", sizes[3], "medium-size image is wrong size")
#     assert_equal("320/1.jpg: 320 240", sizes[4], "small-size image is wrong size")
#     assert_equal("thumb/1.jpg: 160 120", sizes[5], "thumbnail image is wrong size")
#     img = Image.find(1)
#     assert_equal(2560, img.width)
#     assert_equal(1920, img.height)
#     assert_equal(true, img.transferred)
#     for file in [ "thumb/1.jpg", "320/1.jpg", "640/1.jpg", "960/1.jpg",
#                   "1280/1.jpg", "orig/1.jpg", "orig/1.tiff" ]
#       file1 = "#{img_root}/#{file}"
#       file2 = "#{remote_root}1/#{file}"
#       assert_equal(File.size(file1), File.size(file2),
#                    "Failed to transfer #{file} to server 1, size is wrong.")
#     end
#     for file in [ "thumb/1.jpg", "320/1.jpg" ]
#       file1 = "#{img_root}/#{file}"
#       file2 = "#{remote_root}2/#{file}"
#       assert_equal(File.size(file1), File.size(file2),
#                    "Failed to transfer #{file} to server 2, size is wrong.")
#     end
#     # Not implemented yet.
#     # for file in [ "640/1.jpg", "960/1.jpg", "1280/1.jpg", "orig/1.jpg", "orig/1.tiff" ]
#     #   file2 = "#{remote_root}2/#{file}"
#     #   assert(!File.exist?(file2), "Shouldn't have transferred #{file} to server 2.")
#     # end
#   end
# 
#   test "refresh_name_lister_cache" do
#     script = script_file("refresh_name_lister_cache")
#     tempfile = Tempfile.new("test").path
#     output_file = MO.name_lister_cache_file
#     FileUtils.rm(output_file) if File.exist?(output_file)
#     cmd = "#{script} 2>&1 > #{tempfile}"
#     status = system(cmd)
#     errors = File.read(tempfile)
#     assert_block("Something went wrong with #{script}:\n#{errors}") { status && errors.blank? }
#     output = File.read(output_file)
#     fixture = "#{::Rails.root}/test/reports/name_list_data.js"
#     assert_string_equal_file(output, fixture)
#   end
# 
#   test "retransfer_images" do
#     script = script_file("retransfer_images")
#     tempfile = Tempfile.new("test").path
#     local_root = MO.local_image_files
#     remote_root = "#{::Rails.root}/tmp/image_server"
#     # Can't do this, since in unit tests ActiveRecord wraps all work on the
#     # database in a transaction.  Soon as you look at the database it becomes
#     # immune to external changes for the rest of the test.  So we need to be
#     # careful not to even peek at the database until we've run the script.
#     # img1 = Image.find(1)
#     # img2 = Image.find(2)
#     # assert_equal(false, img1.transferred)
#     # assert_equal(false, img2.transferred)
#     system("rm -rf #{remote_root}*")
#     system("rm -rf #{local_root}/*/[12].*")
#     File.open("#{local_root}/orig/1.tiff", "w") { |f| f.write("A") }
#     File.open("#{local_root}/orig/1.jpg",  "w") { |f| f.write("B") }
#     File.open("#{local_root}/1280/1.jpg",  "w") { |f| f.write("C") }
#     File.open("#{local_root}/960/1.jpg",   "w") { |f| f.write("D") }
#     File.open("#{local_root}/640/1.jpg",   "w") { |f| f.write("E") }
#     File.open("#{local_root}/320/1.jpg",   "w") { |f| f.write("F") }
#     File.open("#{local_root}/thumb/1.jpg", "w") { |f| f.write("G") }
#     File.open("#{local_root}/640/2.jpg",   "w") { |f| f.write("H") }
#     File.open("#{local_root}/320/2.jpg",   "w") { |f| f.write("I") }
#     File.open("#{local_root}/thumb/2.jpg", "w") { |f| f.write("J") }
#     cmd = "#{script} 2>&1 > #{tempfile}"
#     status = system(cmd)
#     errors = File.read(tempfile)
#     assert_block("Something went wrong with #{script}:\n#{errors}") { status && errors.blank? }
#     img1 = Image.find(1)
#     img2 = Image.find(2)
#     assert_equal(true, img1.transferred)
#     assert_equal(true, img2.transferred)
#     assert_equal("A", File.read("#{remote_root}1/orig/1.tiff"), "orig/1.tiff wrong for server 1")
#     assert_equal("B", File.read("#{remote_root}1/orig/1.jpg"),  "orig/1.jpg wrong for server 1")
#     assert_equal("C", File.read("#{remote_root}1/1280/1.jpg"),  "1280/1.jpg wrong for server 1")
#     assert_equal("D", File.read("#{remote_root}1/960/1.jpg"),   "960/1.jpg wrong for server 1")
#     assert_equal("E", File.read("#{remote_root}1/640/1.jpg"),   "640/1.jpg wrong for server 1")
#     assert_equal("F", File.read("#{remote_root}1/320/1.jpg"),   "320/1.jpg wrong for server 1")
#     assert_equal("G", File.read("#{remote_root}1/thumb/1.jpg"), "thumb/1.jpg wrong for server 1")
#     assert_equal("H", File.read("#{remote_root}1/640/2.jpg"),   "640/2.jpg wrong for server 1")
#     assert_equal("I", File.read("#{remote_root}1/320/2.jpg"),   "320/2.jpg wrong for server 1")
#     assert_equal("F", File.read("#{remote_root}2/320/1.jpg"),   "320/1.jpg wrong for server 2")
#     assert_equal("G", File.read("#{remote_root}2/thumb/1.jpg"), "thumb/1.jpg wrong for server 2")
#     assert_equal("I", File.read("#{remote_root}2/320/2.jpg"),   "320/2.jpg wrong for server 2")
#     assert_equal("J", File.read("#{remote_root}2/thumb/2.jpg"), "thumb/2.jpg wrong for server 2")
#     # Not implemented yet.
#     # assert(!File.exist?("#{remote_root}2/orig/1.tiff"), "orig/1.tiff shouldnt be on server 2")
#     # assert(!File.exist?("#{remote_root}2/orig/1.jpg"),  "orig/1.jpg shouldnt be on server 2")
#     # assert(!File.exist?("#{remote_root}2/1280/1.jpg"),  "1280/1.jpg shouldnt be on server 2")
#     # assert(!File.exist?("#{remote_root}2/960/1.jpg"),   "960/1.jpg shouldnt be on server 2")
#     # assert(!File.exist?("#{remote_root}2/640/1.jpg"),   "640/1.jpg shouldnt be on server 2")
#     # assert(!File.exist?("#{remote_root}2/640/2.jpg"),   "640/2.jpg shouldnt be on server 2")
#   end
# 
#   test "rotate_image" do
#     script = script_file("rotate_image")
#     tempfile = Tempfile.new("test").path
#     test_image = "#{::Rails.root}/test/images/sticky.jpg"
#     remote_root = "#{::Rails.root}/tmp/image_server"
#     local_root = MO.local_image_files
#     system("rm -rf #{remote_root}*")
#     system("rm -rf #{local_root}/*/1.*")
#     FileUtils.mkpath("#{remote_root}1/orig")
#     FileUtils.cp(test_image, "#{remote_root}1/orig/1.jpg")
#     cmd = "#{script} 1 +90 2>&1 > #{tempfile}"
#     status = system(cmd)
#     errors = File.read(tempfile)
#     assert_block("Something went wrong with #{script}:\n#{errors}") { status && errors.blank? }
#     assert(File.exist?("#{local_root}/orig/1.jpg"))
#     assert(File.exist?("#{local_root}/thumb/1.jpg"))
#     assert(File.exist?("#{remote_root}1/orig/1.jpg"))
#     assert(File.exist?("#{remote_root}1/thumb/1.jpg"))
#     assert(File.exist?("#{remote_root}2/orig/1.jpg"))
#     assert(File.exist?("#{remote_root}2/thumb/1.jpg"))
#     img = Image.find(1)
#     assert_equal(500, img.width)
#     assert_equal(407, img.height)
#     assert_equal(true, img.transferred)
#   end
# 
#   test "verify_images" do
#     script = script_file("verify_images")
#     tempfile = Tempfile.new("test").path
#     local_root = "#{::Rails.root}/tmp/local_images"
#     remote_root = "#{::Rails.root}/tmp/image_server"
#     system("rm -rf #{local_root}")
#     system("rm -rf #{remote_root}*")
#     FileUtils.mkpath("#{local_root}/orig")
#     FileUtils.mkpath("#{local_root}/640")
#     FileUtils.mkpath("#{local_root}/320")
#     File.open("#{local_root}/orig/1.tiff", "w") { |f| f.write("A") }
#     File.open("#{local_root}/orig/1.jpg", "w") { |f| f.write("AB") }
#     File.open("#{local_root}/640/1.jpg", "w") { |f| f.write("ABC") }
#     File.open("#{local_root}/320/1.jpg", "w") { |f| f.write("ABCD") }
#     File.open("#{local_root}/640/2.jpg", "w") { |f| f.write("ABCDE") }
#     File.open("#{local_root}/320/2.jpg", "w") { |f| f.write("ABCDEF") }
#     File.open("#{local_root}/640/3.jpg", "w") { |f| f.write("ABCDEFG") }
#     File.open("#{local_root}/320/3.jpg", "w") { |f| f.write("ABCDEFGH") }
#     cmd = "#{script} -t 2>&1 > #{tempfile}"
#     status = system(cmd)
#     errors = File.read(tempfile)
#     assert_block("Something went wrong with #{script}:\n#{errors}") { status }
#     assert_equal(<<-END.unindent, errors)
#       blah
#     END
#   end
end
