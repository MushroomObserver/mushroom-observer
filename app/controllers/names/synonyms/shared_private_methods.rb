# frozen_string_literal: true

module Names::Synonyms
  module SharedPrivateMethods
    private

    def abort_if_name_locked!(name)
      return false if !name.locked || in_admin_mode?

      flash_error(:permission_denied.t)
      redirect_back_or_default("/")
    end
  end
end
