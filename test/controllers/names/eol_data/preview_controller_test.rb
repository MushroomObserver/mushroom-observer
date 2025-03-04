# frozen_string_literal: true

require("test_helper")

module Names::EolData
  class PreviewControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_eol_preview
      login
      get("show")
    end
  end
end
