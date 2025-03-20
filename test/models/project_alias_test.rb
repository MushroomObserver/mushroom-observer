# frozen_string_literal: true

require("test_helper")

class ProjectAliasTest < ActiveSupport::TestCase
  def test_valid_user_aliases
    pa = ProjectAlias.find_by(target_type: "User")
    assert_equal(User, pa.target.class)
  end

  def test_valid_location_aliases
    pa = ProjectAlias.find_by(target_type: "Location")
    assert_equal(Location, pa.target.class)
  end
end
