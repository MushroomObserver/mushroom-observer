# frozen_string_literal: true

require("test_helper")

module Names
  class EolDataControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_eol
      login
      get("show")
    end
  end
end
