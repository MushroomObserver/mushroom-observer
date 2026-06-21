# frozen_string_literal: true

# Plain `<a>` that opens in a new tab with `rel="noopener noreferrer"`
# baked in. Use via the context-nav dispatcher (Tab#html_options with
# `external: true`) or directly for one-off external links.
#
# @example Direct use
#   render(Components::Link::External.new("GBIF", gbif_url))
#
# @example Via a Tab PORO
#   # Tab sets html_options: { external: true }
#   # Dispatcher routes here automatically.
class Components::Link::External < Components::Base
  def initialize(content, path, **opts)
    super()
    @content = content
    @path = path
    @opts = opts
  end

  def view_template
    link_to(@path,
            target: "_blank",
            rel: "noopener noreferrer",
            **@opts) do
      plain(@content)
    end
  end
end
