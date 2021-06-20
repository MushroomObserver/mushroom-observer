# frozen_string_literal: true

# private methods shared by HerbariaController and subcontrollers
module Herbaria
  module SharedPrivateMethods
    private

    # ---------- Filters -------------------------------------------------------

    def keep_track_of_referrer
      @back = params[:back] || request.referer
    end

    def redirect_to_referrer
      return false if @back.blank?

      redirect_to(@back)
      true
    end

    # ---------- Merges --------------------------------------------------------

    # Used by Herbaria#create, Herbaria#edit, HerbariaMerges#create

    def perform_or_request_merge(src, dest)
      if in_admin_mode? || src.can_merge_into?(dest)
        perform_merge(src, dest)
      else
        request_merge(src, dest)
      end
    end

    def perform_merge(src, dest)
      old_name = src.name_was
      result = dest.merge(src)
      flash_notice(
        :runtime_merge_success.t(
          type: :herbarium, src: old_name, dest: result.name
        )
      )
      result
    end

    def request_merge(src, dest)
      redirect_with_query(
        observer_email_merge_request_path(
          type: :Herbarium, old_id: src.id, new_id: dest.id
        )
      )
      false
    end
  end
end
