# frozen_string_literal: true

require("test_helper")

# The backfill's resume point. A file rather than a column because the
# pass is temporary -- see the class comment.
class Inat::URLBackfillCursorTest < UnitTestCase
  def setup
    @path = Rails.root.join("tmp/url_backfill_cursor_test_#{SecureRandom.hex}")
    @cursor = Inat::URLBackfill::Cursor.new(path: @path)
  end

  def teardown
    FileUtils.rm_f(@path)
  end

  # nil starts the walk at the newest observation.
  def test_reads_nil_when_no_file_exists
    assert_nil(@cursor.read)
  end

  def test_round_trips_an_id
    @cursor.write(396_771_016)

    assert_equal(396_771_016, @cursor.read)
  end

  def test_creates_the_directory_it_needs
    nested = @path.join("deeper/cursor")
    cursor = Inat::URLBackfill::Cursor.new(path: nested)

    cursor.write(5)

    assert_equal(5, cursor.read)
  end

  # A truncated or hand-emptied file resumes from the newest rather than
  # from id 0, which would end the walk immediately.
  def test_reads_nil_from_an_unusable_file
    File.write(@path, "")

    assert_nil(@cursor.read)
  end

  def test_reads_nil_when_the_path_cannot_be_opened
    FileUtils.mkdir_p(@path) # a directory where a file is expected

    assert_nil(@cursor.read)
  ensure
    FileUtils.rm_rf(@path)
  end
end
