# frozen_string_literal: true

class Tab::Name::New < Tab::Base
  def title
    :show_name_add_name.l
  end

  def path
    new_name_path
  end

  def html_options
    { icon: :add }
  end

  def model
    Name
  end
end
