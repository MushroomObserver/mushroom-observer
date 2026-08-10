# frozen_string_literal: true

require("open3")

class FieldSlip
  # Reads a field slip code out of a photo's QR code, using the zbar
  # command-line tool (`zbarimg`). DBG-style voucher slips encode the
  # bare code ("2026-CMS-0219"); MO's own slips encode a /qr/ URL. Both
  # forms are recognized.
  #
  # Inert when zbarimg is not installed (`brew install zbar` /
  # `apt-get install zbar-tools`): callers check `available?` first, so
  # an environment without the binary simply has no QR detection.
  module QRDecoder
    # The 1280px copy first: it decodes printed slip QRs reliably and
    # zbar chews through it several times faster than a full-resolution
    # original -- which matters when the scan runs inline in the
    # observation-create request. Full size is the fallback for a QR
    # too small or soft to survive the downscale -- but only when the
    # original is still on local disk. An archived original is never
    # downloaded for a scan; it just counts as a miss, and the
    # no-slip-detected flash points at the manual scan page.
    SIZES = [:huge, :full_size].freeze

    # The code is the path segment alone -- MO's own /qr/ URLs can
    # carry query params (e.g. ?project=...), which are not part of it.
    MO_QR_URL = %r{\Ahttps?://(?:www\.)?mushroomobserver\.org/qr/([^?#/\s]+)}i

    # The general shape of a printed slip code ("2026-CMS-0219",
    # "NEMF-10222"): one token, letters somewhere (FieldSlip's own
    # validation requires a non-digit character), bounded length.
    CODE_SHAPE = /\A[A-Z0-9][A-Z0-9._-]{3,30}\z/

    def self.available?
      MO.field_slip_qr_detection && zbarimg?
    end

    def self.zbarimg?
      return @zbarimg unless @zbarimg.nil?

      @zbarimg = system("which", "zbarimg", out: File::NULL,
                                            err: File::NULL) || false
    end

    # The slip code in the image's QR code, or nil: no local file, no
    # QR, or QR content that isn't a slip code.
    def self.slip_code_in(image)
      raw_codes(image).filter_map { |text| slip_code_from(text) }.first
    end

    # A bare code is only believed when its prefix names a project --
    # photos contain all kinds of QR codes (product labels, wifi
    # passes), and the project prefix is what separates a slip from
    # noise. An MO /qr/ URL is explicit enough on its own.
    def self.slip_code_from(text)
      text = text.to_s.strip
      url_code = text[MO_QR_URL, 1]
      return url_code.upcase if url_code

      code = text.upcase
      return nil unless code.match?(CODE_SHAPE) && code.match?(/[^\d.-]/)

      prefix = FieldSlip.prefix_for_code(code)
      code if prefix && Project.exists?(field_slip_prefix: prefix)
    end

    # Every QR payload zbar finds, largest available file first,
    # stopping at the first size that decodes anything.
    def self.raw_codes(image)
      return [] unless available?

      SIZES.each do |size|
        path = local_file(image, size)
        next unless path

        codes = scan(path)
        return codes if codes.any?
      end
      []
    end

    # The precedence-resolved URL stops pointing at the local copy the
    # moment an image transfers (production resolves transferred images
    # to the image server), but the file itself stays on this machine's
    # disk until cleanup -- so probe the direct path too, or a fresh
    # upload becomes unreadable within a second of arriving.
    def self.local_file(image, size)
      Image::LocalFile.path(image, size) || direct_path(image, size)
    end

    def self.direct_path(image, size)
      path = image.full_filepath(size)
      path if path && File.exist?(path)
    end

    # -Sdisable -Sqrcode.enable: QR only, so a stray barcode elsewhere
    # in the photo can't answer.
    def self.scan(path)
      out, _err, status = Open3.capture3(
        "zbarimg", "--quiet", "--raw", "-Sdisable", "-Sqrcode.enable", path
      )
      # zbarimg exits 4 when it finds nothing -- not an error here.
      return [] unless status.success?

      out.split("\n").map(&:strip).compact_blank
    end
  end
end
