# frozen_string_literal: true

require("test_helper")
require("set")

module Names::Descriptions
  class MovesControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_try_move_no_permission; end

    def test_move_description_to_new_name; end
    def test_move_description_to_nonexistant_name; end

    def test_move_description_to_new_name_notes_conflict; end
  end
end
