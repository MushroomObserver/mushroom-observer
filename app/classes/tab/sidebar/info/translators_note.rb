# frozen_string_literal: true

# Sidebar info nav: translators-note page.
class Tab::Sidebar::Info::TranslatorsNote < Tab::Base
  def title
    :translators_note_title.t
  end

  def path
    info_translators_note_path
  end
end
