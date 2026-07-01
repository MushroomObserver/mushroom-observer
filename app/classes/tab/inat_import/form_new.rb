# frozen_string_literal: true

# Action-nav for the iNat-import new + confirm forms.
class Tab::InatImport::FormNew < Tab::Collection
  def initialize(has_prior_imports: false)
    super()
    @has_prior_imports = has_prior_imports
  end

  private

  def tabs
    [
      Tab::InatImport::Cancel.new,
      (Tab::InatImport::Index.new if @has_prior_imports)
    ].compact
  end
end
