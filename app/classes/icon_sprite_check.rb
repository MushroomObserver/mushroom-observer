# frozen_string_literal: true

# Components::Icon silently renders nothing when the private
# icon-library sprite isn't present locally -- a dev with no sprite
# sees every icon missing, with no indication why. Checked once at
# server boot by config/initializers/ensure_icon_sprite.rb: fetches
# the sprite via script/dev_setup/sync_mo_icon_library.sh if missing,
# or tells the dev how to fetch it themselves if that fails (no
# icon-library access yet, network issue, etc).
class IconSpriteCheck
  MISSING_MESSAGE = "\n*** Icon sprite not found -- fetching it now " \
                    "(vendor/assets/images/icons/mo-icons.svg)... ***\n"
  FAILURE_MESSAGE = "\n*** Could not fetch the icon sprite automatically " \
                    "-- icons won't render until you do. Run " \
                    "`script/setup --icons-only`, or ask an MO admin " \
                    "for icon-library access if that fails. ***\n"

  def self.sprite_path
    Rails.root.join("vendor/assets/images/icons/mo-icons.svg")
  end

  def self.applicable?(
    env: Rails.env,
    server: !!defined?(Rails::Server),
    sprite_exists: sprite_path.exist?
  )
    env.development? && server && !sprite_exists
  end

  def self.ensure_sprite!
    return unless applicable?

    warn(MISSING_MESSAGE)
    fetch_sprite
    warn(FAILURE_MESSAGE) unless sprite_path.exist?
  end

  def self.fetch_sprite
    system(
      "bash", "-c",
      "source script/dev_setup/sync_mo_icon_library.sh && " \
      "mo_sync_icon_library",
      chdir: Rails.root.to_s
    )
  end
end
