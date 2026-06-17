# frozen_string_literal: true

require("test_helper")

class ProjectAliasTest < ActiveSupport::TestCase
  def test_valid_user_aliases
    pa = ProjectAlias.find_by(target_type: "User")
    assert_instance_of(User, pa.target)
  end

  def test_valid_location_aliases
    pa = ProjectAlias.find_by(target_type: "Location")
    assert_instance_of(Location, pa.target)
  end
end
