# frozen_string_literal: true

class FieldSlip
  # A printed field slip layout: which fields the form carries, where
  # each lands on the Observation, and how to read one from a photo
  # (see FieldSlip::Extractor).
  #
  # Code-defined for now -- adding a layout is a subclass plus a
  # registry entry here. The registry is expected to move to the
  # database eventually, so event organizers can define and share
  # layouts themselves (issue #5024).
  module Template
    REGISTRY = { "mo" => "FieldSlip::Template::Mo",
                 "dbg" => "FieldSlip::Template::Dbg",
                 "nama" => "FieldSlip::Template::Nama" }.freeze

    # Which layout each project's slips are printed on, keyed by the
    # project's field_slip_prefix (stable across environments, unlike
    # ids). A project not listed uses the MO slip, so a photo of a slip
    # on any other layout is rejected at review rather than misread.
    PROJECT_TEMPLATES = {
      "2025-NAMA" => "dbg",
      "2026-CMS" => "dbg",
      "2026-NAMA" => "nama",
      "2026-SMHF" => "dbg"
    }.freeze

    def self.for(key)
      name = REGISTRY[key.to_s] ||
             raise(ArgumentError.new("Unknown field slip template: #{key}"))
      name.constantize.new
    end

    def self.default = self.for(:mo)

    def self.for_project(project)
      self.for(PROJECT_TEMPLATES[project&.field_slip_prefix] || "mo")
    end
  end
end
