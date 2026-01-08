# frozen_string_literal: true

# Table component for rendering data tables with Bootstrap styling.
#
# Uses the Phlex pattern of collecting columns via block, then rendering.
# Columns are defined with headers and content blocks that receive each row.
#
# @example Basic usage
#   render(Components::Table.new(@users)) do |t|
#     t.column("Name") { |user| user.name }
#     t.column("Email") { |user| user.email }
#   end
#
# @example With custom classes
#   render(Components::Table.new(@items, class: "table-sm")) do |t|
#     t.column("Item") { |item| item.name }
#     t.column("Price") { |item| number_to_currency(item.price) }
#   end
#
# @example From ERB
#   <%= render(Components::Table.new(@observations)) do |t| %>
#     <% t.column("Name") do |obs| %>
#       <%= link_to(obs.name, obs) %>
#     <% end %>
#     <% t.column("Date") do |obs| %>
#       <%= obs.when %>
#     <% end %>
#   <% end %>
#
class Components::Table < Components::Base
  def initialize(rows, headers: true, **options)
    super()
    @rows = rows
    @columns = []
    @show_headers = headers
    @options = options
  end

  def view_template(&block)
    # Capture column definitions without outputting anything
    vanish(&block)

    table(**table_attributes) do
      render_thead if @show_headers
      render_tbody
    end
  end

  # Define a column with header text and content block or method symbol.
  # @param header [String] the column header text
  # @param method [Symbol] method to call on each row (alternative to block)
  # @yield [row] block that receives each row and returns cell content
  # @return [nil] returns nil to prevent ERB output
  #
  # @example With block
  #   t.column("Name") { |user| user.name }
  #
  # @example With method symbol
  #   t.column("Name", &:name)
  #
  def column(header, &content)
    @columns << { header: header, content: content }
    nil
  end

  private

  def table_attributes
    base_class = "table"
    custom_class = @options[:class]
    combined_class = custom_class ? "#{base_class} #{custom_class}" : base_class

    @options.merge(class: combined_class).except(:id).tap do |attrs|
      attrs[:id] = @options[:id] if @options[:id]
    end
  end

  def render_thead
    thead do
      tr do
        @columns.each do |column|
          th { column[:header] }
        end
      end
    end
  end

  def render_tbody
    tbody do
      @rows.each do |row|
        tr do
          @columns.each do |column|
            td { column[:content].call(row) }
          end
        end
      end
    end
  end
end
