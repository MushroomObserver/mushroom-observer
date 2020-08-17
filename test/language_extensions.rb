# frozen_string_literal: true

# stop-gap fix for
# TypeError: superclass mismatch for class Language
#   /vagrant/mushroom-observer/app/models/language.rb:27:in `<top (required)>'
# when running rake
require("language.rb")

class Language
  @@verbose_messages = []

  def self.override_input_files
    @@localization_files = {}
    @@export_files = {}
  end

  def self.reset_input_file_override
    @@localization_files = nil
    @@export_files = nil
  end

  def self.last_update=(val)
    @@last_update = val
  end

  def self.clear_verbose_messages
    @@verbose_messages = []
  end

  def self.verbose_messages
    @@verbose_messages
  end

  def verbose(msg)
    @@verbose_messages << msg
  end

  def send_private(*args)
    send(*args)
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
