# frozen_string_literal: true

require("test_helper")

class InatPageParserTest < UnitTestCase
  def test_inat_username_required
    import = inat_imports(:ollie_inat_import)
    assert_raises(ArgumentError) do
      Inat::PageParser.new(import)
    end
  end
end
