# frozen_string_literal: true

# Sidebar admin nav: licenses index.
class Tab::Sidebar::Admin::Licenses < Tab::Base
  def title
    :licenses.ti
  end

  def path
    licenses_path
  end
end
