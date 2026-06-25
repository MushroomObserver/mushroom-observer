# frozen_string_literal: true

# Base class for `Views::Controllers::*` Phlex view classes and
# other view-layer classes under `Views::*` that render content
# (layouts' sub-pieces, sidebar items, etc.). Inherits from
# `Components::Base` so view classes get the same Phlex/Rails wiring
# as generic UI components.
#
# Per-concern setters (e.g. `add_pagination`) live on
# `Views::FullPageBase::*` modules — action views set; sub-partials
# read via `Components::PaginatedResults`.
class Views::Base < Components::Base
  # Rebuilds the current request URL with the given args merged /
  # cleared (e.g. `reload_with_args(merge: nil)` strips the `?merge=`
  # param). Used by the herbaria index merge-mode Alert + language
  # picker.
  def reload_with_args(new_args)
    uri = request.url.sub(%r{^\w+:/+[^/]+}, "")
    add_args_to_url(uri, new_args)
  end
end
