# frozen_string_literal: true

# "Turn admin mode on/off" link in the user-nav dropdown. The
# `in_admin_mode?` flag is request-scoped, so the caller passes it.
class Tab::UserNav::AdminMode < Tab::Base
  def initialize(in_admin_mode: false)
    super()
    @in_admin_mode = in_admin_mode
  end

  def title
    @in_admin_mode ? :app_turn_admin_off.t : :app_turn_admin_on.t
  end

  def path
    admin_mode_path(**args)
  end

  # Stable selector class regardless of on/off toggle state — title
  # (and therefore the auto-derived class) flips between "Turn Admin
  # Mode On"/"Off", but callers need one consistent class to target.
  def alt_title
    "admin_mode"
  end

  # Toggling admin mode changes the session's theme/asset state, so
  # Turbo Drive's head-merging on the redirected page can corrupt
  # stylesheets. Opt this button out of Turbo entirely.
  def html_options
    { button: :post, data: { turbo: false } }
  end

  private

  def args
    @in_admin_mode ? { turn_off: true } : { turn_on: true }
  end
end
