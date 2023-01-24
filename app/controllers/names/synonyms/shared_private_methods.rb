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

    # Post a comment after approval or deprecation if the user entered one.
    def post_comment(action, name, message)
      summary = :"name_#{action}_comment_summary".l
      Comment.create!(target: name,
                      summary: summary,
                      comment: message)
    end
  end
end
