# frozen_string_literal: true

# stop-gap fix for
# TypeError: superclass mismatch for class Language
#   /vagrant/mushroom-observer/app/models/language.rb:27:in `<top (required)>'
# when running rake
require("language")

class Language
  @verbose_messages = []

  def self.override_input_files
    @localization_files = {}
    @export_files = {}
  end

  def self.reset_input_file_override
    @localization_files = nil
    @export_files = nil
  end

  def self.clear_verbose_messages
    @verbose_messages = []
  end

  class << self
    attr_reader :verbose_messages
  end

  def verbose(msg)
    # Anchored to Language explicitly, not self.class -- a class-
    # instance-variable isn't shared with any subclass the way a
    # class variable was, so self.class would silently read a
    # different (uninitialized) copy if this were ever called on an
    # instance of a Language subclass. No such subclass exists today,
    # but there's no reason to make this fragile against one existing
    # tomorrow when anchoring explicitly costs nothing.
    Language.verbose_messages << msg
  end

  def send_private(*)
    send(*)
  end

  def init_check_export_line(pass, in_tag)
    @pass = pass
    @in_tag = in_tag
    @line_number = 0
  end

  def get_check_export_line_status
    [@pass, @in_tag]
  end
end
