# frozen_string_literal: true

# "Donate" page link.
class Tab::Support::Donate < Tab::Base
  def title
    :donate_tab.t
  end

  def path
    support_donate_path
  end
end
