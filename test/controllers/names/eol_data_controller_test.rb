# frozen_string_literal: true

require("test_helper")
require("set")

module Names
  class EolDataControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_eol
      login
      get("eol")
    end
  end
end
