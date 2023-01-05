# frozen_string_literal: true

module Names::Synonyms
  module SharedPrivateMethods
    private

    def find_name!
      @name = find_or_goto_index(Name, params[:id].to_s)
    end

    def abort_if_name_locked!(name)
      return false if !name.locked || in_admin_mode?

      flash_error(:permission_denied.t)
      redirect_back_or_default("/")
    end
  end
end
