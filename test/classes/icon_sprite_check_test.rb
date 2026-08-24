# frozen_string_literal: true

require("test_helper")

class IconSpriteCheckTest < UnitTestCase
  def test_applicable_when_dev_server_boot_and_sprite_missing
    assert(
      IconSpriteCheck.applicable?(
        env: ActiveSupport::StringInquirer.new("development"),
        server: true, sprite_exists: false
      )
    )
  end

  def test_not_applicable_when_sprite_already_present
    assert_not(
      IconSpriteCheck.applicable?(
        env: ActiveSupport::StringInquirer.new("development"),
        server: true, sprite_exists: true
      )
    )
  end

  def test_not_applicable_outside_server_boot
    assert_not(
      IconSpriteCheck.applicable?(
        env: ActiveSupport::StringInquirer.new("development"),
        server: false, sprite_exists: false
      )
    )
  end

  def test_not_applicable_outside_development
    assert_not(
      IconSpriteCheck.applicable?(
        env: ActiveSupport::StringInquirer.new("test"),
        server: true, sprite_exists: false
      )
    )
  end

  def test_ensure_sprite_fetches_and_stays_silent_on_success
    IconSpriteCheck.stub(:applicable?, true) do
      IconSpriteCheck.stub(:fetch_sprite, nil) do
        IconSpriteCheck.stub(:sprite_path, Pathname.new(__FILE__)) do
          assert_output(nil, IconSpriteCheck::MISSING_MESSAGE) do
            IconSpriteCheck.ensure_sprite!
          end
        end
      end
    end
  end

  def test_ensure_sprite_warns_again_on_fetch_failure
    IconSpriteCheck.stub(:applicable?, true) do
      IconSpriteCheck.stub(:fetch_sprite, nil) do
        IconSpriteCheck.stub(:sprite_path,
                             Pathname.new("/nonexistent/mo-icons.svg")) do
          expected = IconSpriteCheck::MISSING_MESSAGE +
                     IconSpriteCheck::FAILURE_MESSAGE
          assert_output(nil, expected) do
            IconSpriteCheck.ensure_sprite!
          end
        end
      end
    end
  end

  def test_ensure_sprite_silent_when_not_applicable
    IconSpriteCheck.stub(:applicable?, false) do
      assert_silent do
        IconSpriteCheck.ensure_sprite!
      end
    end
  end

  def test_fetch_sprite_calls_system_with_sync_script
    called_with = nil
    stub_system = lambda do |*args, **kwargs|
      called_with = [args, kwargs]
      true
    end

    IconSpriteCheck.stub(:system, stub_system) do
      IconSpriteCheck.fetch_sprite
    end

    assert_equal(
      [["bash", "-c",
        "source script/dev_setup_components/sync_mo_icon_library.sh && " \
        "mo_sync_icon_library"],
       { chdir: Rails.root.to_s }],
      called_with
    )
  end
end
