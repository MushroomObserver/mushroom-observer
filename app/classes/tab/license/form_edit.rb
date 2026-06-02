# frozen_string_literal: true

# Action-nav for the license edit form.
class Tab::License::FormEdit < Tab::Collection
  def initialize(license:)
    super()
    @license = license
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @license),
     Tab::License::Index.new]
  end
end
