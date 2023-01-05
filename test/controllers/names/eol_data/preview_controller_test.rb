# frozen_string_literal: true

require("test_helper")
require("set")

module Names::EolData
  class PreviewControllerTest < FunctionalTestCase
    include ObjectLinkHelper

  def test_eol_preview
    login
    get("eol_preview")
  end

  end
end
