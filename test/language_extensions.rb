# encoding: utf-8

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

  def self.last_update=(x)
    @@last_update = x
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
    @pass, @in_tag, @line_number = pass, in_tag, 0
  end

  def get_check_export_line_status
    return @pass, @in_tag
  end
end

