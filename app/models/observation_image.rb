# frozen_string_literal: true

# Glue table between observations and images.
class ObservationImage < ApplicationRecord
  belongs_to :observation
  belongs_to :image

  # A newly attached photo may carry a field slip QR code that tells MO
  # which slip -- and so which project -- the observation belongs to
  # (see DetectFieldSlipQRJob). Only worth asking while the observation
  # has no occurrence, and only where zbar is installed, so environments
  # without it enqueue nothing.
  after_create_commit :detect_field_slip_qr

  private

  def detect_field_slip_qr
    return unless FieldSlip::QRDecoder.available?
    return if observation.nil? || observation.occurrence_id

    DetectFieldSlipQRJob.perform_later(observation.id)
  end
end
