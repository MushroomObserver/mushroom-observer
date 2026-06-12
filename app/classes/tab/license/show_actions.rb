# frozen_string_literal: true

# Action-nav for the license show page. Adds a destroy tab iff the
# license isn't in use.
class Tab::License::ShowActions < Tab::Collection
  def initialize(license:)
    super()
    @license = license
  end

  private

  def tabs
    base = [Tab::License::Index.new,
            Tab::License::New.new,
            Tab::License::Edit.new(license: @license)]
    return base if @license.in_use?

    base + [Tab::License::Destroy.new(license: @license)]
  end
end
