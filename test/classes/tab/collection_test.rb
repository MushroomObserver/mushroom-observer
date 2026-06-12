# frozen_string_literal: true

require("test_helper")

# Covers Tab::Collection default behavior — `#tabs` is abstract,
# Enumerable bridges to the legacy array shape via `#each`.
module Tab
  class CollectionTest < UnitTestCase
    class Bare < Tab::Collection
    end

    def test_tabs_raises_not_implemented_on_each
      e = assert_raises(NotImplementedError) { Bare.new.to_a }

      assert_match(/Bare#tabs/, e.message)
    end
  end
end
