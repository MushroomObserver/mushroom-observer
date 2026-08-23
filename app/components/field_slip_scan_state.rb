# frozen_string_literal: true

# The scan-state buttons for one photo that already has a field slip
# read: the way to the review form (complete), the self-refreshing
# status page (pending), or the error page (failed), styled like the
# Read Field Slip button they sit beside. Renders nothing when there is
# no read. `offer_retry:` adds a Retry button to the failed state, for
# pages that have no Read Field Slip button of their own.
class Components::FieldSlipScanState < Components::Base
  prop :image, ::Image
  prop :extract, _Nilable(::FieldSlipExtract), default: nil
  prop :offer_retry, _Boolean, default: true

  def view_template
    return unless @extract

    if @extract.complete?
      view_button(:field_slip_scan_review)
    elsif @extract.failed?
      view_button(:field_slip_scan_failed)
      retry_button if @offer_retry
    else
      view_button(:field_slip_scan_reading)
    end
  end

  private

  def view_button(label)
    Button(type: :get, name: label.l,
           target: edit_image_field_slip_extract_path(@image.id))
  end

  def retry_button
    Button(type: :post, name: :field_slip_scan_retry.l, class: "ml-2",
           target: image_field_slip_extract_path(@image.id))
  end
end
