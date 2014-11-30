# encoding: utf-8
require 'test_helper'

class ScriptTest < UnitTestCase
  DATABASE_CONFIG = YAML::load(IO.read("#{::Rails.root}/config/database.yml"))['test']

  def script_file(cmd)
    "#{::Rails.root}/script/#{cmd}"
  end

  def local_root
    "#{::Rails.root}/public/test_images"
  end

  def remote_root
    "#{::Rails.root}/public/test_server"
  end

  def setup
    FileUtils.rm_rf(local_root)
    FileUtils.rm_rf("#{remote_root}1")
    FileUtils.rm_rf("#{remote_root}2")
    for subdir in %w( thumb 320 640 960 1280 orig )
      FileUtils.mkpath("#{local_root}/#{subdir}")
      FileUtils.mkpath("#{remote_root}1/#{subdir}")
      FileUtils.mkpath("#{remote_root}2/#{subdir}")
    end
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
    FileUtils.rm_rf(local_root)
    FileUtils.rm_rf("#{remote_root}1")
    FileUtils.rm_rf("#{remote_root}2")
  end

################################################################################

  test "process_image" do
    script = script_file("process_image")
    tempfile = Tempfile.new("test").path
    original_image = "#{::Rails.root}/test/images/pleopsidium.tiff"
    FileUtils.cp(original_image, "#{local_root}/orig/1.tiff")
    cmd = "#{script} 1 tiff 1 2>&1 > #{tempfile}"
    status = system(cmd)
    errors = File.read(tempfile)
    assert("Something went wrong with #{script}:\n#{errors}") { status && errors.blank? }
    File.open(tempfile, "w") do |file|
      file.puts "#{local_root}/orig/1.jpg"
      file.puts "#{local_root}/1280/1.jpg"
      file.puts "#{local_root}/960/1.jpg"
      file.puts "#{local_root}/640/1.jpg"
      file.puts "#{local_root}/320/1.jpg"
      file.puts "#{local_root}/thumb/1.jpg"
    end
    sizes = File.readlines("| #{script_file('jpegsize')} -f #{tempfile}").map do |line|
      line[local_root.length+1..-1].chomp
    end
    assert_equal("orig/1.jpg: 2560 1920", sizes[0], "full-size image is wrong size")
    assert_equal("1280/1.jpg: 1280 960", sizes[1], "huge-size image is wrong size")
    assert_equal("960/1.jpg: 960 720", sizes[2], "large-size image is wrong size")
    assert_equal("640/1.jpg: 640 480", sizes[3], "medium-size image is wrong size")
    assert_equal("320/1.jpg: 320 240", sizes[4], "small-size image is wrong size")
    assert_equal("thumb/1.jpg: 160 120", sizes[5], "thumbnail image is wrong size")
    img = Image.find(1)
    assert_equal(2560, img.width)
    assert_equal(1920, img.height)
    assert_equal(true, img.transferred)
    for file in [ "thumb/1.jpg", "320/1.jpg", "640/1.jpg", "960/1.jpg",
                  "1280/1.jpg", "orig/1.jpg", "orig/1.tiff" ]
      file1 = "#{local_root}/#{file}"
      file2 = "#{remote_root}1/#{file}"
      assert_equal(File.size(file1), File.size(file2),
                   "Failed to transfer #{file} to server 1, size is wrong.")
    end
    for file in [ "thumb/1.jpg", "320/1.jpg", "640/1.jpg" ]
      file1 = "#{local_root}/#{file}"
      file2 = "#{remote_root}2/#{file}"
      assert_equal(File.size(file1), File.size(file2),
                   "Failed to transfer #{file} to server 2, size is wrong.")
    end
    for file in [ "960/1.jpg", "1280/1.jpg", "orig/1.jpg", "orig/1.tiff" ]
      file2 = "#{remote_root}2/#{file}"
      assert(!File.exist?(file2), "Shouldn't have transferred #{file} to server 2.")
    end
  end

  test "retransfer_images" do
    script = script_file("retransfer_images")
    tempfile = Tempfile.new("test").path
    # Can't do this, since in unit tests ActiveRecord wraps all work on the
    # database in a transaction.  Soon as you look at the database it becomes
    # immune to external changes for the rest of the test.  So we need to be
    # careful not to even peek at the database until we've run the script.
    # img1 = Image.find(1)
    # img2 = Image.find(2)
    # assert_equal(false, img1.transferred)
    # assert_equal(false, img2.transferred)
    File.open("#{local_root}/orig/1.tiff", "w") { |f| f.write("A") }
    File.open("#{local_root}/orig/1.jpg",  "w") { |f| f.write("B") }
    File.open("#{local_root}/1280/1.jpg",  "w") { |f| f.write("C") }
    File.open("#{local_root}/960/1.jpg",   "w") { |f| f.write("D") }
    File.open("#{local_root}/640/1.jpg",   "w") { |f| f.write("E") }
    File.open("#{local_root}/320/1.jpg",   "w") { |f| f.write("F") }
    File.open("#{local_root}/thumb/1.jpg", "w") { |f| f.write("G") }
    File.open("#{local_root}/960/2.jpg",   "w") { |f| f.write("H") }
    File.open("#{local_root}/640/2.jpg",   "w") { |f| f.write("I") }
    File.open("#{local_root}/320/2.jpg",   "w") { |f| f.write("J") }
    File.open("#{local_root}/thumb/2.jpg", "w") { |f| f.write("K") }
    cmd = "#{script} 2>&1 > #{tempfile}"
    status = system(cmd)
    errors = File.read(tempfile)
    assert("Something went wrong with #{script}:\n#{errors}") { status && errors.blank? }
    img1 = Image.find(1)
    img2 = Image.find(2)
    assert_equal(true, img1.transferred)
    assert_equal(true, img2.transferred)
    assert_equal("A", File.read("#{remote_root}1/orig/1.tiff"), "orig/1.tiff wrong for server 1")
    assert_equal("B", File.read("#{remote_root}1/orig/1.jpg"),  "orig/1.jpg wrong for server 1")
    assert_equal("C", File.read("#{remote_root}1/1280/1.jpg"),  "1280/1.jpg wrong for server 1")
    assert_equal("D", File.read("#{remote_root}1/960/1.jpg"),   "960/1.jpg wrong for server 1")
    assert_equal("E", File.read("#{remote_root}1/640/1.jpg"),   "640/1.jpg wrong for server 1")
    assert_equal("F", File.read("#{remote_root}1/320/1.jpg"),   "320/1.jpg wrong for server 1")
    assert_equal("G", File.read("#{remote_root}1/thumb/1.jpg"), "thumb/1.jpg wrong for server 1")
    assert_equal("H", File.read("#{remote_root}1/960/2.jpg"),   "960/2.jpg wrong for server 1")
    assert_equal("I", File.read("#{remote_root}1/640/2.jpg"),   "640/2.jpg wrong for server 1")
    assert_equal("J", File.read("#{remote_root}1/320/2.jpg"),   "320/2.jpg wrong for server 1")
    assert_equal("K", File.read("#{remote_root}1/thumb/2.jpg"), "thumb/2.jpg wrong for server 1")
    assert_equal("E", File.read("#{remote_root}2/640/1.jpg"),   "640/1.jpg wrong for server 2")
    assert_equal("F", File.read("#{remote_root}2/320/1.jpg"),   "320/1.jpg wrong for server 2")
    assert_equal("G", File.read("#{remote_root}2/thumb/1.jpg"), "thumb/1.jpg wrong for server 2")
    assert_equal("I", File.read("#{remote_root}2/640/2.jpg"),   "640/2.jpg wrong for server 2")
    assert_equal("J", File.read("#{remote_root}2/320/2.jpg"),   "320/2.jpg wrong for server 2")
    assert_equal("K", File.read("#{remote_root}2/thumb/2.jpg"), "thumb/2.jpg wrong for server 2")
    assert(!File.exist?("#{remote_root}2/orig/1.tiff"), "orig/1.jpg shouldnt be on server 2")
    assert(!File.exist?("#{remote_root}2/orig/1.jpg"),  "orig/1.jpg shouldnt be on server 2")
    assert(!File.exist?("#{remote_root}2/1280/1.jpg"),  "1280/1.jpg shouldnt be on server 2")
    assert(!File.exist?("#{remote_root}2/960/1.jpg"),   "960/1.jpg shouldnt be on server 2")
    assert(!File.exist?("#{remote_root}2/960/2.jpg"),   "960/2.jpg shouldnt be on server 2")
  end

  test "rotate_image" do
    script = script_file("rotate_image")
    tempfile = Tempfile.new("test").path
    test_image = "#{::Rails.root}/test/images/sticky.jpg"
    FileUtils.cp(test_image, "#{remote_root}1/orig/1.jpg")
    cmd = "#{script} 1 +90 2>&1 > #{tempfile}"
    status = system(cmd)
    errors = File.read(tempfile)
    assert("Something went wrong with #{script}:\n#{errors}") { status && errors.blank? }
    assert(File.exist?("#{local_root}/orig/1.jpg"))
    assert(File.exist?("#{local_root}/thumb/1.jpg"))
    assert(File.exist?("#{remote_root}1/orig/1.jpg"))
    assert(File.exist?("#{remote_root}1/thumb/1.jpg"))
    assert(!File.exist?("#{remote_root}2/orig/1.jpg"))
    assert(File.exist?("#{remote_root}2/thumb/1.jpg"))
    img = Image.find(1)
    assert_equal(500, img.width)
    assert_equal(407, img.height)
    assert_equal(true, img.transferred)
  end

  test "verify_images" do
    script = script_file("verify_images")
    tempfile = Tempfile.new("test").path
    [ 'thumb', '320', '640', '960', '1280', 'orig' ].each do |subdir|
      FileUtils.mkpath("#{local_root}/#{subdir}")
    end
    File.open("#{local_root}/orig/2.tiff", "w") { |f| f.write("A") }
    File.open("#{local_root}/orig/2.jpg",  "w") { |f| f.write("AB") }
    File.open("#{local_root}/960/2.jpg",   "w") { |f| f.write("ABC") }
    File.open("#{local_root}/640/2.jpg",   "w") { |f| f.write("ABCD") }
    File.open("#{local_root}/320/2.jpg",   "w") { |f| f.write("ABCDE") }
    File.open("#{local_root}/960/3.jpg",   "w") { |f| f.write("ABCDEF") }
    File.open("#{local_root}/640/3.jpg",   "w") { |f| f.write("ABCDEFG") }
    File.open("#{local_root}/320/3.jpg",   "w") { |f| f.write("ABCDEFGH") }
    File.open("#{local_root}/960/4.jpg",   "w") { |f| f.write("ABCDEFGHI") }
    File.open("#{local_root}/640/4.jpg",   "w") { |f| f.write("ABCDEFGHIJ") }
    File.open("#{local_root}/320/4.jpg",   "w") { |f| f.write("ABCDEFGHIJK") }
    File.open("#{remote_root}1/960/1.jpg", "w") { |f| f.write("correct") }
    File.open("#{remote_root}1/640/1.jpg", "w") { |f| f.write("correct") }
    File.open("#{remote_root}1/320/1.jpg", "w") { |f| f.write("correct") }
    File.open("#{remote_root}1/960/2.jpg", "w") { |f| f.write("ABC") }
    File.open("#{remote_root}1/640/2.jpg", "w") { |f| f.write("ABCD") }
    File.open("#{remote_root}1/320/2.jpg", "w") { |f| f.write("ABCDE") }
    File.open("#{remote_root}1/960/3.jpg", "w") { |f| f.write("ABCDEF") }
    File.open("#{remote_root}1/640/3.jpg", "w") { |f| f.write("ABCDEFG") }
    File.open("#{remote_root}1/320/3.jpg", "w") { |f| f.write("ABCDEFGH") }
    File.open("#{remote_root}1/960/4.jpg", "w") { |f| f.write("allcorrupted!") }
    File.open("#{remote_root}1/640/4.jpg", "w") { |f| f.write("allcorrupted!") }
    File.open("#{remote_root}1/320/4.jpg", "w") { |f| f.write("allcorrupted!") }
    File.open("#{remote_root}2/640/1.jpg", "w") { |f| f.write("correct") }
    File.open("#{remote_root}2/320/1.jpg", "w") { |f| f.write("correct") }
    File.open("#{remote_root}2/640/2.jpg", "w") { |f| f.write("ABCD") }
    File.open("#{remote_root}2/320/2.jpg", "w") { |f| f.write("ABCDE") }
    File.open("#{remote_root}2/640/3.jpg", "w") { |f| f.write("allcorrupted!") }
    File.open("#{remote_root}2/320/3.jpg", "w") { |f| f.write("allcorrupted!") }
    cmd = "#{script} --verbose 2>&1 > #{tempfile}"
    status = system(cmd)
    errors = File.read(tempfile)
    assert("Something went wrong with #{script}:\n#{errors}") { status }
    assert_equal(<<-END.unindent, errors)
      Uploading 320/4.jpg to remote1
      Uploading 320/3.jpg to remote2
      Uploading 320/4.jpg to remote2
      Uploading 640/4.jpg to remote1
      Uploading 640/3.jpg to remote2
      Uploading 640/4.jpg to remote2
      Uploading 960/4.jpg to remote1
      Uploading orig/2.jpg to remote1
      Uploading orig/2.tiff to remote1
      Deleting 640/2.jpg
      Deleting 960/2.jpg
      Deleting 960/3.jpg
    END
  end
end
