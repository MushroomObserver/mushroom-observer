# frozen_string_literal: true

require("test_helper")

class Inat
  class PageParserTest < UnitTestCase
    def test_raises_if_not_own_import_has_no_username_or_ids
      import = inat_imports(:dick_inat_import).tap do |i|
        i.own_observations = false
        i.inat_username = ""
        i.inat_ids = ""
      end

      assert_raises(ArgumentError) { PageParser.new(import) }
    end

    def test_does_not_raise_if_not_own_import_has_username
      import = inat_imports(:dick_inat_import).tap do |i|
        i.own_observations = false
        i.inat_username = "some_user"
        i.inat_ids = ""
      end

      assert_nothing_raised { PageParser.new(import) }
    end

    def test_does_not_raise_if_not_own_import_has_ids
      import = inat_imports(:dick_inat_import).tap do |i|
        i.own_observations = false
        i.inat_username = ""
        i.inat_ids = "123,456"
      end

      assert_nothing_raised { PageParser.new(import) }
    end
  end
end
