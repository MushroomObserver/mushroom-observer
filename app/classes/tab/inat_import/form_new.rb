# frozen_string_literal: true

# Action-nav for the iNat-import new + confirm forms.
class Tab::InatImport::FormNew < Tab::Collection
  private

  def tabs
    [Tab::InatImport::Cancel.new]
  end
end
