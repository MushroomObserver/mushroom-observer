# frozen_string_literal: true

# private methods shared by HerbariaController and subcontrollers
module Herbaria::SharedPrivateMethods
  def keep_track_of_referrer
    @back = params[:back] || request.referer
  end

  def redirect_to_referrer
    return false if @back.blank?

    redirect_to(@back)
    true
  end

  def redirect_to_show_herbarium(herbarium = @herbarium)
    redirect_with_query(herbarium_path(herbarium))
  end

  def redirect_to_herbarium_index(herbarium = @herbarium)
    redirect_with_query(filtered_herbaria_path(id: herbarium.try(&:id)))
  end

  def perform_or_request_merge(this, that)
    if in_admin_mode? || this.can_merge_into?(that)
      perform_merge(this, that)
    else
      request_merge(this, that)
    end
  end

  def perform_merge(this, that)
    old_name = this.name_was
    result = this.merge(that)
    flash_notice(:runtime_merge_success.t(
                 type: :herbarium, this: old_name, that: result.name)
    )
    result
  end

  def request_merge(this, that)
    redirect_with_query(
      observer_email_merge_request_path(
        type: :Herbarium, old_id: this.id, new_id: that.id
      )
    )
    false
  end
end
