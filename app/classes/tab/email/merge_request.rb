# frozen_string_literal: true

# Action-nav for the admin email merge-request form. `old_obj` is
# the soon-to-be-merged-away parent (Name, Herbarium, etc.).
class Tab::Email::MergeRequest < Tab::Collection
  def initialize(old_obj:)
    super()
    @old_obj = old_obj
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @old_obj)]
  end
end
