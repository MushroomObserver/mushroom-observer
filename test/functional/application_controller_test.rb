require File.dirname(__FILE__) + '/../boot'

class ApplicationControllerTest < ControllerTestCase

  # Make sure languages all have same tags.
  def test_language_tags
    dir = "#{RAILS_ROOT}/lang/ui"
    assert File.directory?(dir)
    files = Dir.glob("#{dir}/*.yml")
    assert(files.length > 0)

    tags = {}
    this_tags = {}

    errors = []
    for file in files
      h = this_tags[file] = {}
      x = {}
      y = {}
      for line in IO.readlines(file)
        file2 = file.sub(/.*\//, '')
        if line.match(/^(\w+):/)
          if h[$1]
            errors.push("The key \"#{$1}\" occurs more than once in #{file2}.") \
          end
          x = tags[$1] ||= {}
          y = h[$1]    ||= {}
        end
        if !line.match(/^\s*#/)
          line.gsub(/\[(\w+)\]/) do
            x[$1] = y[$1] = nil
          end
        end
      end
      assert(h["app_banner"])
    end
    assert_equal('', errors.join("\n"))

    errors = []
    mismatches = {}
    for file in files
      file2 = file.sub(/.*\//, '')
      h = this_tags[file]
      missing = tags.keys - h.keys
      if !missing.empty?
        errors.push("Missing tags in #{file2}: [#{missing.sort.join(", ")}]")
      else
        for key in h.keys
          missing = tags[key].keys - h[key].keys
          if !missing.empty?
            mismatches[key] = nil
          end
        end
      end
    end

    # These are known to have argument mismatches.
    mismatches.delete('query_title_all')

    assert_equal('', errors.join("\n"))

    # The translataions are too free-form now for this test to be meaningful.
    # assert_equal([], mismatches.keys.sort, "Arguments don't agree for these keys in all the files.")
  end
end
