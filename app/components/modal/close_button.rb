# frozen_string_literal: true

# Footer "Cancel" button for a `Components::Modal` — the DRY
# counterpart to `Modal#close_button` (the header's `×` icon).
# Different role: `close_button` is header-icon-only chrome;
# `CloseButton` is the labeled Cancel button that sits in
# `.modal-footer` alongside Submit.
#
# Not a BS4-migration-safety fix on its own — `data-dismiss="modal"`
# is unchanged in BS4 (only BS5 renames it to `data-bs-dismiss`).
# Worth doing anyway for DRY (5 identical call sites) and to derisk
# that eventual BS5 rename to one place.
#
# @example Plain dismiss-only Cancel (the common case)
#   render(Components::Modal::CloseButton.new)
#
# @example Navigational Cancel — dismisses the modal AND follows a
#   real link (e.g. the caller wants Cancel to redirect back to a
#   listing page, not just close the modal in place)
#   render(Components::Modal::CloseButton.new(target: cancel_path))
class Components::Modal::CloseButton < Components::Base
  prop :target, _Nilable(_Union(String, Hash, ::AbstractModel)), default: nil
  prop :name, String, default: -> { :CANCEL.l }
  # `_Any?`, not bare `_Any` -- Literal's `_Any` excludes `NilClass`,
  # so a caller passing an explicit `key: nil` (not just omitting the
  # key) would otherwise raise a Literal::TypeError.
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template
    Button(**button_attrs)
  end

  private

  def button_attrs
    attrs = @attributes.dup
    attrs[:data] = (attrs[:data] || {}).merge(dismiss: "modal")
    attrs[:name] = @name
    if @target
      attrs[:type] = :get
      attrs[:target] = @target
    end
    attrs
  end
end
