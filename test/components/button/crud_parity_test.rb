# frozen_string_literal: true

require("test_helper")

# Pre-refactor CRUDButton implementation, verbatim from main.
# Used as the "before" state in parity comparisons.
class LegacyCRUDButton < Components::Base
  NAMED_ROUTE_ACTIONS = [:edit, :new, :download].freeze
  LEGACY_SHOW_OBS_EDITABLES = %w[
    collection_numbers herbarium_records sequences external_links
  ].freeze

  def initialize(name:, target:, method: :post, confirm: nil, **args,
                 &block)
    super()
    @name = name
    @target = target
    @method = method
    @confirm = confirm
    @args = args
    @block = block
  end

  def view_template
    @block&.call
    if @method == :get
      render_link
    else
      render_form_button
    end
  end

  private

  def render_link
    link_to(path, link_html_options) { button_content }
  end

  def render_form_button
    button_to(path, button_html_options) { button_content }
  end

  def link_html_options
    base = { class: merged_class }
    base.merge!(tooltip_data) if @args[:icon]
    base.deep_merge(@args.except(*ignored_arg_keys))
  end

  def merged_class
    class_names(identifier, @args[:btn], @args[:class])
  end

  def ignored_arg_keys
    [:class, :icon, :icon_class, :action, :back, :btn]
  end

  def tooltip_data
    {
      title: @name,
      data: { toggle: "tooltip", placement: "top", title: @name }
    }
  end

  def button_html_options
    form_data = { turbo: true }
    form_data[:turbo_confirm] = @confirm if @confirm

    button_data = { toggle: "tooltip", placement: "top", title: @name }
    if @confirm
      button_data[:turbo_confirm_title] = @confirm
      button_data[:turbo_confirm_button] = @name
    end

    {
      method: @method,
      class: merged_class,
      form: { data: form_data },
      data: button_data
    }.merge(@args.except(*ignored_arg_keys))
  end

  def button_content
    capture do
      if @args[:icon]
        render(Components::Icon.new(
                 type: @args[:icon], html_class: @args[:icon_class]
               ))
        span(class: "sr-only") { trusted_html(@name) }
      else
        trusted_html(@name)
      end
    end
  end

  def path
    if @target.is_a?(String) || @target.is_a?(Hash)
      @target
    else
      target_path
    end
  end

  def identifier
    if @target.is_a?(String) || @target.is_a?(Hash)
      ""
    else
      "#{action}_#{@target.type_tag}_link_#{@target.id}"
    end
  end

  def action
    @args[:action] || @method
  end

  def target_path
    send(:"#{path_prefix}#{@target.type_tag}_path",
         @target.id, **path_args)
  end

  def path_args
    back = @args[:back] || default_back_param
    back ? { back: back } : {}
  end

  def default_back_param
    return nil unless back_eligible?
    return nil unless LEGACY_SHOW_OBS_EDITABLES.include?(controller_name)

    case action_name
    when "show" then :show
    when "index" then :index
    end
  end

  def back_eligible?
    [:edit, :destroy].include?(@args[:action]) &&
      !@target.is_a?(String) && !@target.is_a?(Hash)
  end

  def path_prefix
    NAMED_ROUTE_ACTIONS.include?(@args[:action]) ? "#{action}_" : ""
  end
end

class LegacyCRUDButtonGet < LegacyCRUDButton
  def initialize(target:, name:, **args)
    super(target: target, name: name, method: :get, **args)
  end
end

class LegacyCRUDButtonEdit < LegacyCRUDButtonGet
  def initialize(target:, name: nil, **args)
    args[:icon] = :edit unless args.key?(:icon)
    super(target: target,
          name: name || default_name(target),
          action: :edit,
          **args)
  end

  private

  def default_name(target)
    return :EDIT.l if target.is_a?(String) || target.is_a?(Hash)

    :edit_object.t(type: target.type_tag)
  end
end

class LegacyCRUDButtonDelete < LegacyCRUDButton
  def initialize(target:, name: nil, **args)
    args[:class] = [args[:class], "text-danger"].compact.join(" ").strip
    args[:confirm] ||= :are_you_sure.l
    args[:icon] = :delete unless args.key?(:icon)
    super(
      target: target,
      name: name || default_name(target),
      method: :delete,
      action: :destroy,
      **args
    )
  end

  private

  def default_name(target)
    return :DESTROY.l if target.is_a?(String) || target.is_a?(Hash)

    :destroy_object.t(type: target.type_tag)
  end
end

class LegacyCRUDButtonPost < LegacyCRUDButton
  def initialize(target:, name:, **args)
    super(target: target, name: name, method: :post, **args)
  end
end

class LegacyCRUDButtonPut < LegacyCRUDButton
  def initialize(target:, name:, **args)
    super(target: target, name: name, method: :put, **args)
  end
end

class LegacyCRUDButtonPatch < LegacyCRUDButton
  def initialize(target:, name:, **args)
    super(target: target, name: name, method: :patch, **args)
  end
end

class LegacyCRUDButtonDownload < LegacyCRUDButtonGet
  def initialize(target:, name: nil, **args)
    args[:icon] = :download unless args.key?(:icon)
    super(target: target,
          name: name.presence || :DOWNLOAD.t,
          action: :download,
          **args)
  end
end

class LegacyCRUDButtonNew < LegacyCRUDButtonGet
  def initialize(target:, name: nil, **args)
    args[:icon] = :add unless args.key?(:icon)
    super(target: target,
          name: name || :ADD.l,
          action: :new,
          **args)
  end
end

# Pre-refactor Link::Modal implementation, verbatim from main.
class LegacyLinkModal < Components::Base
  def initialize(identifier, name = nil, path = nil, **args)
    super()
    @identifier = identifier
    @name = name
    @path = path
    @args = args
  end

  def view_template
    link_to(@name, @path, **link_args)
  end

  private

  def link_args
    @args.deep_merge(data: modal_data)
  end

  def modal_data
    {
      modal: "modal_#{@identifier}",
      controller: "modal-toggle",
      action: "modal-toggle#showModal:prevent"
    }
  end
end

# -----------------------------------------------------------------------
# Parity tests
# -----------------------------------------------------------------------
# Each test section compares the pre-refactor "Legacy" class output
# against the current Button::* component. Two scenarios per component:
#   1. Defaults — no overrides; exercises the common path
#   2. Overrides — icon: nil (text-only), extra class, extra data attr,
#      or custom name; exercises the opts forwarding path

class Components::Button::CrudParityTest < ComponentTestCase
  def setup
    super
    @herb = herbaria(:nybg_herbarium)
    @proj = projects(:eol_project)
    @path = "/some/path"
  end

  # --- Button::Edit ---

  def test_edit_parity_defaults
    old_html = render(LegacyCRUDButtonEdit.new(target: @herb))
    new_html = render(Components::Button::Edit.new(target: @herb,
                                                   variant: :strip))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "edit_defaults")
  end

  def test_edit_parity_text_only_with_extra_class
    old_html = render(LegacyCRUDButtonEdit.new(
                        target: @herb,
                        name: "Custom Edit",
                        icon: nil,
                        class: "mt-2"
                      ))
    new_html = render(Components::Button::Edit.new(
                        target: @herb,
                        name: "Custom Edit",
                        variant: :strip,
                        icon: nil,
                        class: "mt-2"
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "edit_overrides")
  end

  # --- Button::Delete ---

  def test_delete_parity_defaults
    old_html = render(LegacyCRUDButtonDelete.new(target: @herb))
    new_html = render(Components::Button::Delete.new(target: @herb,
                                                     variant: :strip))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "form",
                                   label: "delete_defaults")
  end

  def test_delete_parity_custom_confirm_and_name
    old_html = render(LegacyCRUDButtonDelete.new(
                        target: @herb,
                        name: :REMOVE.l,
                        confirm: "Remove this herbarium?",
                        icon: nil,
                        class: "d-inline"
                      ))
    new_html = render(Components::Button::Delete.new(
                        target: @herb,
                        name: :REMOVE.l,
                        confirm: "Remove this herbarium?",
                        variant: :strip,
                        icon: nil,
                        class: "d-inline"
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "form",
                                   label: "delete_overrides")
  end

  # --- Button::Post ---

  def test_post_parity_defaults
    old_html = render(LegacyCRUDButtonPost.new(
                        name: :show_project_join.l,
                        target: @path,
                        btn: "btn btn-default"
                      ))
    new_html = render(Components::Button::Post.new(
                        name: :show_project_join.l,
                        target: @path
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "form",
                                   label: "post_defaults")
  end

  def test_post_parity_with_confirm_and_extra_data
    old_html = render(LegacyCRUDButtonPost.new(
                        name: "Submit",
                        target: @path,
                        btn: "btn btn-default",
                        confirm: "Are you sure?",
                        class: "mt-3"
                      ))
    new_html = render(Components::Button::Post.new(
                        name: "Submit",
                        target: @path,
                        confirm: "Are you sure?",
                        class: "mt-3"
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "form",
                                   label: "post_overrides")
  end

  # --- Button::Patch ---

  def test_patch_parity_defaults
    old_html = render(LegacyCRUDButtonPatch.new(
                        name: "Update",
                        target: @path,
                        btn: "btn btn-default"
                      ))
    new_html = render(Components::Button::Patch.new(
                        name: "Update",
                        target: @path
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "form",
                                   label: "patch_defaults")
  end

  def test_patch_parity_with_confirm
    old_html = render(LegacyCRUDButtonPatch.new(
                        name: "Update",
                        target: @path,
                        btn: "btn btn-default",
                        confirm: "Really update?"
                      ))
    new_html = render(Components::Button::Patch.new(
                        name: "Update",
                        target: @path,
                        confirm: "Really update?"
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "form",
                                   label: "patch_overrides")
  end

  # --- Button::Put ---

  def test_put_parity_defaults
    old_html = render(LegacyCRUDButtonPut.new(
                        name: "Replace",
                        target: @path,
                        btn: "btn btn-default"
                      ))
    new_html = render(Components::Button::Put.new(
                        name: "Replace",
                        target: @path
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "form",
                                   label: "put_defaults")
  end

  def test_put_parity_with_confirm_and_extra_class
    old_html = render(LegacyCRUDButtonPut.new(
                        name: "Replace",
                        target: @path,
                        btn: "btn btn-default",
                        confirm: "Replace everything?",
                        class: "ml-2"
                      ))
    new_html = render(Components::Button::Put.new(
                        name: "Replace",
                        target: @path,
                        confirm: "Replace everything?",
                        class: "ml-2"
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "form",
                                   label: "put_overrides")
  end

  # --- Button::Get (plain string target) ---

  def test_get_parity_defaults
    old_html = render(LegacyCRUDButtonGet.new(
                        name: "View",
                        target: @path,
                        btn: "btn btn-default"
                      ))
    new_html = render(Components::Button::Get.new(
                        name: "View",
                        target: @path
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "get_defaults")
  end

  def test_get_parity_with_icon_and_extra_attrs
    old_html = render(LegacyCRUDButtonGet.new(
                        name: "View",
                        target: @path,
                        btn: "btn btn-default",
                        icon: :info,
                        class: "my-1",
                        data: { extra: "value" }
                      ))
    new_html = render(Components::Button::Get.new(
                        name: "View",
                        target: @path,
                        icon: :info,
                        class: "my-1",
                        data: { extra: "value" }
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "get_overrides")
  end

  # --- Button::Download (explicit-path target) ---
  #
  # Old CRUDButton::Download had no btn: default (no button frame).
  # The real caller (SpeciesLists::Details) now passes variant: :strip
  # explicitly to preserve that appearance.

  def test_download_parity_defaults
    dl_path = "/species_lists/123/download"
    old_html = render(LegacyCRUDButtonDownload.new(target: dl_path))
    new_html = render(Components::Button::Download.new(
                        target: dl_path,
                        variant: :strip
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "download_defaults")
  end

  def test_download_parity_custom_name_text_only
    dl_path = "/species_lists/456/download"
    old_html = render(LegacyCRUDButtonDownload.new(
                        target: dl_path,
                        name: "Export CSV",
                        icon: nil
                      ))
    new_html = render(Components::Button::Download.new(
                        name: "Export CSV",
                        target: dl_path,
                        variant: :strip,
                        icon: nil
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "download_overrides")
  end

  # --- Button::New (explicit-path target) ---
  #
  # Old CRUDButton::New had no btn: default (no button frame).
  # Pass variant: :strip to the new component to match that shape.

  def test_new_parity_defaults
    new_path = routes.new_herbarium_path
    old_html = render(LegacyCRUDButtonNew.new(target: new_path))
    new_html = render(Components::Button::New.new(
                        target: new_path,
                        variant: :strip
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "new_defaults")
  end

  def test_new_parity_text_only_with_extra_class
    new_path = routes.new_herbarium_path
    old_html = render(LegacyCRUDButtonNew.new(
                        target: new_path,
                        name: "Add Herbarium",
                        icon: nil,
                        class: "mt-2"
                      ))
    new_html = render(Components::Button::New.new(
                        target: new_path,
                        name: "Add Herbarium",
                        variant: :strip,
                        icon: nil,
                        class: "mt-2"
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "new_overrides")
  end

  # --- Button::ModalToggle vs LegacyLinkModal ---
  #
  # Real-world callers always passed `class: "btn btn-default ..."` to
  # Link::Modal explicitly. The new ModalToggle gets that via the
  # nil-variant default inherited from Button::Get.

  def test_modal_toggle_parity_defaults
    modal_path = "/projects/1/members/trust"
    # Old callers explicitly threaded "btn btn-default" through the
    # class kwarg; new callers rely on Button::Get's variant: :default.
    old_html = render(LegacyLinkModal.new(
                        "trust_settings",
                        "Trust Settings",
                        modal_path,
                        class: "btn btn-default"
                      ))
    new_html = render(Components::Button::ModalToggle.new(
                        name: "Trust Settings",
                        target: modal_path,
                        modal_id: "trust_settings"
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "modal_toggle_defaults")
  end

  def test_modal_toggle_parity_with_extra_class_and_data
    modal_path = "/comments/new?target=1&type=Observation"
    old_html = render(LegacyLinkModal.new(
                        "comment",
                        "Add Comment",
                        modal_path,
                        class: "btn btn-default my-2",
                        data: { extra: "sprinkle" }
                      ))
    new_html = render(Components::Button::ModalToggle.new(
                        name: "Add Comment",
                        target: modal_path,
                        modal_id: "comment",
                        class: "my-2",
                        data: { extra: "sprinkle" }
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "modal_toggle_overrides")
  end
end
