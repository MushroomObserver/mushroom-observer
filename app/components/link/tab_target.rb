# frozen_string_literal: true

# Shared "accept a Tab PORO as a shortcut for title/path/html_options"
# logic for `Components::Link::Get`. Raises unless a `tab` or a full
# title/path pair was given -- no known caller ever relies on a
# silent no-op here, and a missing tab/title/path is a construction
# bug that should fail loudly rather than render an empty link.
module Components::Link::TabTarget
  private

  def resolve_tab_args(tab, title, path, opts)
    if tab
      [title || tab.title, path || tab.path, tab.html_options.merge(opts)]
    elsif title && path
      [title, path, opts]
    else
      raise(ArgumentError.new(
              "#{self.class} requires either tab: or both name: and " \
              "target:"
            ))
    end
  end
end
