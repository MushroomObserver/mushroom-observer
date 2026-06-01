# frozen_string_literal: true

class Tab::Name::NewTracker < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :show_name_email_tracking.t
  end

  def path
    new_tracker_of_name_path(@name.id)
  end

  def html_options
    { icon: :tracking }
  end

  def model
    @name
  end
end
