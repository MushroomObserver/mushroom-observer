#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to migrate Panel components from prop-based to block-based API
#
# Usage: ruby script/migrate_panel_to_blocks.rb path/to/file.erb

require "fileutils"

class PanelMigrator
  def initialize(file_path)
    @file_path = file_path
    @content = File.read(file_path)
    @changes = []
  end

  def migrate!
    puts "Migrating: #{@file_path}"

    # Pattern 1: Simple panels with just heading and body
    migrate_simple_panels_with_heading_and_body

    # Pattern 2: Panels with heading and footer
    migrate_panels_with_heading_and_footer

    # Pattern 3: Panels with heading_links
    migrate_panels_with_heading_links

    # Pattern 4: Panels with formatted_content: true
    migrate_panels_with_formatted_content

    if @changes.any?
      backup_file
      File.write(@file_path, @content)
      puts "✓ Migrated #{@changes.length} panels"
      @changes.each { |change| puts "  - #{change}" }
    else
      puts "✗ No changes needed"
    end
  end

  private

  def backup_file
    backup_path = "#{@file_path}.backup"
    FileUtils.cp(@file_path, backup_path)
    puts "  Backup created: #{backup_path}"
  end

  def migrate_simple_panels_with_heading_and_body
    # Match: render(Components::Panel.new(heading: ..., ...)) do ... end
    # This is the simplest case - heading + body content in block

    pattern = /
      <%=\s*render\(\s*
      Components::Panel\.new\(
        \s*heading:\s*([^,\)]+?)       # heading value
        (?:,\s*inner_id:\s*([^,\)]+?))? # optional inner_id
        (?:,\s*panel_class:\s*([^,\)]+?))? # optional panel_class
      \s*\)
      \s*\)\s*do\s*%>
      (.*?)                           # body content
      <%\s*end\s*%>
    /xm

    @content.gsub!(pattern) do |match|
      heading = Regexp.last_match(1)
      inner_id = Regexp.last_match(2)
      panel_class = Regexp.last_match(3)
      body = Regexp.last_match(4)

      @changes << "Simple panel with heading"

      # Build new panel props
      props = []
      props << "inner_id: #{inner_id}" if inner_id
      props << "panel_class: #{panel_class}" if panel_class
      props_str = props.any? ? props.join(", ") : ""

      <<~ERB.strip
        <%= render(Components::Panel.new(#{props_str})) do |panel| %>
          <%= panel.render(Components::PanelHeading.new { #{heading} }) %>
          <%= panel.render(Components::PanelBody.new do %>
        #{body}  <% end) %>
        <% end %>
      ERB
    end
  end

  def migrate_panels_with_heading_and_footer
    # Match panels with heading and footer props
    pattern = /
      <%=\s*render\(\s*
      Components::Panel\.new\(
        \s*heading:\s*([^,]+?),        # heading
        .*?
        footer:\s*([^,\)]+?)           # footer
        .*?
      \s*\)
      \s*\)\s*do\s*%>
      (.*?)                           # body
      <%\s*end\s*%>
    /xm

    @content.gsub!(pattern) do |match|
      heading = Regexp.last_match(1)
      footer = Regexp.last_match(2)
      body = Regexp.last_match(3)

      @changes << "Panel with heading and footer"

      <<~ERB.strip
        <%= render(Components::Panel.new) do |panel| %>
          <%= panel.render(Components::PanelHeading.new { #{heading} }) %>
          <%= panel.render(Components::PanelBody.new do %>
        #{body}  <% end) %>
          <%= panel.render(Components::PanelFooter.new { #{footer} }) %>
        <% end %>
      ERB
    end
  end

  def migrate_panels_with_heading_links
    # This one is complex - heading_links needs to be moved into the heading
    puts "  ⚠ Warning: Found heading_links - requires manual review"
  end

  def migrate_panels_with_formatted_content
    # formatted_content: true means content is already HTML-safe
    # We need to use .html_safe in the new API
    puts "  ⚠ Warning: Found formatted_content - requires manual review"
  end
end

# Run migration if called directly
if __FILE__ == $PROGRAM_NAME
  if ARGV.empty?
    puts "Usage: ruby script/migrate_panel_to_blocks.rb path/to/file.erb"
    puts ""
    puts "Or migrate all files:"
    puts "  ruby script/migrate_panel_to_blocks.rb app/views/**/*.erb"
    exit 1
  end

  ARGV.each do |file_path|
    if File.exist?(file_path)
      migrator = PanelMigrator.new(file_path)
      migrator.migrate!
      puts ""
    else
      puts "File not found: #{file_path}"
    end
  end
end
