#!/usr/bin/env ruby
# frozen_string_literal: true

# Write a QR code for a URL to a standalone image file.
#
#   bundle exec ruby script/qr_code.rb <url> [options]
#
#     -o, --out PATH      output file (default projects/qr/<slug>.png)
#     -s, --scale N       pixels per QR module, png only (default 8)
#     -q, --quiet-zone N  border modules (default 4, the spec minimum)
#     -l, --level L       error correction: l, m, q, h (default m)
#         --svg           write SVG instead of PNG
#
# The two QR codes already in the app both draw into a Prawn canvas
# (ObservationLabels::QRCodeField, Prawn::FieldSlipCard#qr_svg) and
# cannot hand back a file, so this covers the cases outside a PDF:
# checking what a route resolves to, pointing a phone at a dev server,
# a one-off code for a sign. No Rails -- rqrcode and chunky_png are the
# whole dependency list, so it starts instantly.

require("fileutils")
require("rqrcode")
require("uri")

DEFAULTS = { scale: 8, quiet_zone: 4, level: "m", svg: false,
             out: nil }.freeze
VALUE_FLAGS = { "-o" => :out, "--out" => :out,
                "-s" => :scale, "--scale" => :scale,
                "-q" => :quiet_zone, "--quiet-zone" => :quiet_zone,
                "-l" => :level, "--level" => :level }.freeze
INTEGER_FLAGS = [:scale, :quiet_zone].freeze
LEVELS = %w[l m q h].freeze
OUT_DIR = File.join("projects", "qr")

def usage(reason = nil)
  warn("error: #{reason}\n") if reason.is_a?(String)
  warn(<<~USAGE)
    usage: bundle exec ruby script/qr_code.rb <url> [options]

      -o, --out PATH      output file (default #{OUT_DIR}/<slug>.png)
      -s, --scale N       pixels per module, png only (default 8)
      -q, --quiet-zone N  border modules (default 4)
      -l, --level L       error correction l|m|q|h (default m)
          --svg           write SVG instead of PNG
  USAGE
  exit(reason.is_a?(Integer) ? reason : 1)
end

def parse_argv(argv)
  opts = DEFAULTS.dup
  url = nil
  until argv.empty?
    arg = argv.shift
    if (flag = VALUE_FLAGS[arg])
      opts[flag] = cast(flag, argv.shift)
    else
      url = parse_bare(arg, opts, url)
    end
  end
  validate(url, opts)
end

# A typo must abort rather than quietly produce a code for the wrong
# url -- the image looks plausible whatever it encodes.
def parse_bare(arg, opts, url)
  case arg
  when "--svg" then opts[:svg] = true
  when "-h", "--help" then usage(0)
  else
    usage("unexpected argument #{arg.inspect}") if url || arg.start_with?("-")
    return arg
  end
  url
end

def cast(flag, value)
  usage("#{flag} needs a value") if value.nil?
  return Integer(value) if INTEGER_FLAGS.include?(flag)

  flag == :level ? value.downcase : value
end

def validate(url, opts)
  usage("no url given") unless url
  unless LEVELS.include?(opts[:level])
    usage("level must be one of #{LEVELS.join(" ")}")
  end

  [url, opts]
end

# A filename that says which url it encodes, so a directory of these
# stays readable.
def default_out(url, svg)
  extension = svg ? "svg" : "png"
  uri = URI.parse(url)
  slug = [uri.host, uri.path].join("-").
         gsub(/[^a-zA-Z0-9]+/, "-").gsub(/\A-|-\z/, "")
  File.join(OUT_DIR, "#{slug.empty? ? "qr" : slug}.#{extension}")
rescue URI::InvalidURIError
  File.join(OUT_DIR, "qr.#{extension}")
end

def write_svg(code, out, opts)
  File.write(out, code.as_svg(module_size: opts[:scale], standalone: true,
                              use_path: true,
                              offset: opts[:quiet_zone] * opts[:scale]))
end

def write_png(code, out, opts)
  png = code.as_png(bit_depth: 1, border_modules: opts[:quiet_zone],
                    color_mode: ChunkyPNG::COLOR_GRAYSCALE,
                    color: "black", fill: "white",
                    module_px_size: opts[:scale])
  File.binwrite(out, png.to_s)
end

# Version and module count say whether a url is pushing the code denser
# than a phone will read at the size it is printed.
def report(code, url, out, opts)
  modules = code.modules.size
  puts("wrote #{out}")
  puts("  url      #{url}")
  puts("  version  #{code.qrcode.version} (#{modules}x#{modules} modules), " \
       "level #{opts[:level].upcase}")
  puts("  size     #{File.size(out)} bytes")
end

url, opts = parse_argv(ARGV)
out = opts[:out] || default_out(url, opts[:svg])
FileUtils.mkdir_p(File.dirname(out))
code = RQRCode::QRCode.new(url, level: opts[:level].to_sym)
opts[:svg] ? write_svg(code, out, opts) : write_png(code, out, opts)
report(code, url, out, opts)
