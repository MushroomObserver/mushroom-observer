# frozen_string_literal: true

require("test_helper")
require("set")

module Locations::Descriptions
  class MovesControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_try_move_no_permission; end

    def test_move_description_to_new_location; end
    def test_move_description_to_nonexistant_location; end

    def test_move_description_to_new_location_notes_conflict; end
  end
end
