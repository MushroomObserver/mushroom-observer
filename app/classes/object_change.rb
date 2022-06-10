# frozen_string_literal: true

# Encapsulates a change in an object
class ObjectChange
  attr_reader :object, :old_clone, :new_clone

  def initialize(obj, old_version, new_version)
    @object = obj
    @old_clone = obj&.revert_clone(old_version)
    @new_clone = obj&.revert_clone(new_version)
  end
end
