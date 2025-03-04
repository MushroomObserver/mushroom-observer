# frozen_string_literal: true

require("test_helper")

module Locations::Descriptions
  class MovesControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_form_permissions; end

    def test_move_descriptions_permissions; end

    def test_move_description_to_nonexistant_location; end

    def test_move_description_replacing_default; end
  end
end
