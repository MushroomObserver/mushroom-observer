require File.dirname(__FILE__) + '/../boot'

class ApplicationControllerTest < ControllerTestCase

  def assert_user_search(pat, expect)
    result = []
    @controller.test_calc_condition(pat, ['u.name'], ['users'], result, Set.new())
    assert_equal(expect, result.first)
  end

  def assert_location_search(pat, expect)
    result = []
    @controller.test_calc_condition(pat, ['l.name', 'o.where'], ['locations'], result, Set.new())
    assert_equal(expect, result.first)
  end

  def assert_google_search(pat, expect)
    result = []
    @controller.test_calc_condition(pat, ['o.notes'], ['comments'], result, Set.new())
    assert_equal(expect, result.first)
  end

  def assert_content_search(pat, expect)
    result = []
    @controller.test_calc_condition(pat, ['o.notes', 'c.body'], ['comments'], result, Set.new())
    assert_equal(expect, result.first)
  end

################################################################################

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
    assert_equal('', errors.join("\n"))
    assert_equal([], mismatches.keys.sort, "Arguents don't agree for these keys in all the files.")
  end

  # Test fancy syntax in advanced search feature.
  def test_calc_condition
    assert_user_search('rolf', "u.name like '%rolf%'")
    assert_user_search('-rolf', "u.name like '%-rolf%'")
    assert_user_search('rolf hobbes', "u.name like '%rolf hobbes%'")
    assert_user_search('rolf*hobbes', "u.name like '%rolf%hobbes%'")
    assert_user_search("rolf hobbe's", "u.name like '%rolf hobbe\\'s%'")
    assert_user_search("rolf or hobbes", "u.name like '%rolf or hobbes%'")
    assert_user_search("rolf OR hobbes", "(u.name like '%rolf%' or u.name like '%hobbes%')")
    assert_user_search("one two OR three four", "(u.name like '%one two%' or u.name like '%three four%')")

    assert_location_search('here', "(l.name like '%here%' or o.where like '%here%')")
    assert_location_search('here or there', "(l.name like '%here or there%' or o.where like '%here or there%')")
    assert_location_search('here OR there', "(l.name like '%here%' or o.where like '%here%' or l.name like '%there%' or o.where like '%there%')")

    assert_google_search('aaa', "o.notes like '%aaa%'")
    assert_google_search('aaa bbb', "(o.notes like '%aaa%' and o.notes like '%bbb%')")
    assert_google_search('aaa  bbb', "(o.notes like '%aaa%' and o.notes like '%bbb%')")

    assert_google_search('aaa or bbb', "(o.notes like '%aaa%' and o.notes like '%or%' and o.notes like '%bbb%')")
    assert_google_search('aaa OR bbb', "(o.notes like '%aaa%' or o.notes like '%bbb%')")
    assert_google_search('aaa*bbb', "o.notes like '%aaa%bbb%'")
    assert_google_search('-aaa', "o.notes not like '%aaa%'")
    assert_google_search('"aaa bbb"', "o.notes like '%aaa bbb%'")
    assert_google_search('"aaa  bbb"', "o.notes like '%aaa  bbb%'")
    assert_google_search('-"aaa bbb"', "o.notes not like '%aaa bbb%'")
    assert_google_search('-"aaa*bbb"', "o.notes not like '%aaa%bbb%'")
    assert_google_search('-', "o.notes like '%-%'")
    assert_google_search('- -', "(o.notes like '%-%' and o.notes like '%-%')")
    assert_google_search('"- -"', "o.notes like '%- -%'")
    assert_google_search('aaa bbb OR ccc ddd', "(o.notes like '%aaa%' and (o.notes like '%bbb%' or o.notes like '%ccc%') and o.notes like '%ddd%')")
    assert_google_search('"aaa bbb" OR "ccc ddd"', "(o.notes like '%aaa bbb%' or o.notes like '%ccc ddd%')")
    assert_google_search('"aaa bbb" OR -"ccc ddd"', "(o.notes like '%aaa bbb%' or o.notes not like '%ccc ddd%')")

    assert_content_search('aaa', "(o.notes like '%aaa%' or c.body like '%aaa%')")
    assert_content_search('aaa bbb', "((o.notes like '%aaa%' or c.body like '%aaa%') and (o.notes like '%bbb%' or c.body like '%bbb%'))")
    assert_content_search('aaa or bbb', "((o.notes like '%aaa%' or c.body like '%aaa%') and (o.notes like '%or%' or c.body like '%or%') and (o.notes like '%bbb%' or c.body like '%bbb%'))")
    assert_content_search('aaa OR bbb', "(o.notes like '%aaa%' or c.body like '%aaa%' or o.notes like '%bbb%' or c.body like '%bbb%')")
    assert_content_search('"aaa OR bbb"', "(o.notes like '%aaa OR bbb%' or c.body like '%aaa OR bbb%')")
    assert_content_search('aaa OR bbb OR ccc', "(o.notes like '%aaa%' or c.body like '%aaa%' or o.notes like '%bbb%' or c.body like '%bbb%' or o.notes like '%ccc%' or c.body like '%ccc%')")
    assert_content_search('aaa "b b" OR ccc', "((o.notes like '%aaa%' or c.body like '%aaa%') and (o.notes like '%b b%' or c.body like '%b b%' or o.notes like '%ccc%' or c.body like '%ccc%'))")
    assert_content_search('aaa OR -bbb ccc', "((o.notes like '%aaa%' or c.body like '%aaa%' or o.notes not like '%bbb%' or c.body not like '%bbb%') and (o.notes like '%ccc%' or c.body like '%ccc%'))")
  end
end
