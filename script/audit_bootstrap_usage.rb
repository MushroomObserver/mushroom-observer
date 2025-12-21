#!/usr/bin/env ruby
# frozen_string_literal: true

# Bootstrap Usage Audit Script
# =============================
# This script audits all views and partials for Bootstrap class usage
# to inform the Phlex migration and Bootstrap upgrade strategy.
#
# Deliverables:
# - Complete inventory of Bootstrap classes used
# - Usage frequency for component prioritization
# - Bootstrap 3-specific class identification
# - ERB view → Phlex component mapping recommendations

require "pathname"

# Bootstrap 3 component patterns and their classifications
BOOTSTRAP_COMPONENTS = {
  # Layout & Grid
  "container" => { category: "Layout", bs3_specific: false, phlex_target: "Components::Container" },
  "container-fluid" => { category: "Layout", bs3_specific: false, phlex_target: "Components::Container" },
  "row" => { category: "Layout", bs3_specific: false, phlex_target: "Components::Row" },
  "col-xs-" => { category: "Grid", bs3_specific: true, phlex_target: "Components::Column", bs4_replacement: "col-" },
  "col-sm-" => { category: "Grid", bs3_specific: false, phlex_target: "Components::Column" },
  "col-md-" => { category: "Grid", bs3_specific: false, phlex_target: "Components::Column" },
  "col-lg-" => { category: "Grid", bs3_specific: false, phlex_target: "Components::Column" },

  # Buttons
  "btn" => { category: "Buttons", bs3_specific: false, phlex_target: "Components::Button" },
  "btn-default" => { category: "Buttons", bs3_specific: true, phlex_target: "Components::Button", bs4_replacement: "btn-secondary" },
  "btn-primary" => { category: "Buttons", bs3_specific: false, phlex_target: "Components::Button" },
  "btn-success" => { category: "Buttons", bs3_specific: false, phlex_target: "Components::Button" },
  "btn-info" => { category: "Buttons", bs3_specific: false, phlex_target: "Components::Button" },
  "btn-warning" => { category: "Buttons", bs3_specific: false, phlex_target: "Components::Button" },
  "btn-danger" => { category: "Buttons", bs3_specific: false, phlex_target: "Components::Button" },
  "btn-link" => { category: "Buttons", bs3_specific: false, phlex_target: "Components::Button" },
  "btn-lg" => { category: "Buttons", bs3_specific: false, phlex_target: "Components::Button" },
  "btn-sm" => { category: "Buttons", bs3_specific: false, phlex_target: "Components::Button" },
  "btn-xs" => { category: "Buttons", bs3_specific: true, phlex_target: "Components::Button", bs4_replacement: "btn-sm" },
  "btn-block" => { category: "Buttons", bs3_specific: false, phlex_target: "Components::Button" },
  "btn-group" => { category: "Buttons", bs3_specific: false, phlex_target: "Components::ButtonGroup" },

  # Forms
  "form-control" => { category: "Forms", bs3_specific: false, phlex_target: "ApplicationForm::*Field" },
  "form-group" => { category: "Forms", bs3_specific: false, phlex_target: "ApplicationForm::*Field" },
  "form-horizontal" => { category: "Forms", bs3_specific: true, phlex_target: "Components::Form", bs4_replacement: "remove class, add .row to .form-group" },
  "form-inline" => { category: "Forms", bs3_specific: false, phlex_target: "Components::Form" },
  "control-label" => { category: "Forms", bs3_specific: true, phlex_target: "ApplicationForm::*Field", bs4_replacement: "col-form-label" },
  "help-block" => { category: "Forms", bs3_specific: true, phlex_target: "ApplicationForm::*Field", bs4_replacement: "form-text" },
  "has-error" => { category: "Forms", bs3_specific: true, phlex_target: "ApplicationForm::*Field", bs4_replacement: "is-invalid" },
  "has-success" => { category: "Forms", bs3_specific: true, phlex_target: "ApplicationForm::*Field", bs4_replacement: "is-valid" },
  "has-warning" => { category: "Forms", bs3_specific: true, phlex_target: "ApplicationForm::*Field", bs4_replacement: "is-warning" },
  "input-group" => { category: "Forms", bs3_specific: false, phlex_target: "Components::InputGroup" },

  # Navigation
  "nav" => { category: "Navigation", bs3_specific: false, phlex_target: "Components::Nav" },
  "navbar" => { category: "Navigation", bs3_specific: false, phlex_target: "Components::Navbar" },
  "navbar-default" => { category: "Navigation", bs3_specific: true, phlex_target: "Components::Navbar", bs4_replacement: "navbar-light" },
  "navbar-inverse" => { category: "Navigation", bs3_specific: true, phlex_target: "Components::Navbar", bs4_replacement: "navbar-dark" },
  "navbar-toggle" => { category: "Navigation", bs3_specific: true, phlex_target: "Components::Navbar", bs4_replacement: "navbar-toggler" },
  "navbar-header" => { category: "Navigation", bs3_specific: true, phlex_target: "Components::Navbar", bs4_replacement: "remove" },
  "nav-tabs" => { category: "Navigation", bs3_specific: false, phlex_target: "Components::Tabs" },
  "nav-pills" => { category: "Navigation", bs3_specific: false, phlex_target: "Components::Nav" },
  "nav-stacked" => { category: "Navigation", bs3_specific: true, phlex_target: "Components::Nav", bs4_replacement: "flex-column" },
  "breadcrumb" => { category: "Navigation", bs3_specific: false, phlex_target: "Components::Breadcrumb" },
  "pagination" => { category: "Navigation", bs3_specific: false, phlex_target: "Components::Pagination" },

  # Panels/Cards
  "panel" => { category: "Panels", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card" },
  "panel-default" => { category: "Panels", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card" },
  "panel-primary" => { category: "Panels", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card bg-primary" },
  "panel-success" => { category: "Panels", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card bg-success" },
  "panel-info" => { category: "Panels", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card bg-info" },
  "panel-warning" => { category: "Panels", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card bg-warning" },
  "panel-danger" => { category: "Panels", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card bg-danger" },
  "panel-heading" => { category: "Panels", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card-header" },
  "panel-title" => { category: "Panels", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card-title" },
  "panel-body" => { category: "Panels", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card-body" },
  "panel-footer" => { category: "Panels", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card-footer" },

  # Alerts
  "alert" => { category: "Alerts", bs3_specific: false, phlex_target: "Components::Alert" },
  "alert-success" => { category: "Alerts", bs3_specific: false, phlex_target: "Components::Alert" },
  "alert-info" => { category: "Alerts", bs3_specific: false, phlex_target: "Components::Alert" },
  "alert-warning" => { category: "Alerts", bs3_specific: false, phlex_target: "Components::Alert" },
  "alert-danger" => { category: "Alerts", bs3_specific: false, phlex_target: "Components::Alert" },
  "alert-dismissible" => { category: "Alerts", bs3_specific: false, phlex_target: "Components::Alert" },

  # Labels/Badges
  "label" => { category: "Badges", bs3_specific: true, phlex_target: "Components::Badge", bs4_replacement: "badge" },
  "label-default" => { category: "Badges", bs3_specific: true, phlex_target: "Components::Badge", bs4_replacement: "badge badge-secondary" },
  "label-primary" => { category: "Badges", bs3_specific: true, phlex_target: "Components::Badge", bs4_replacement: "badge badge-primary" },
  "label-success" => { category: "Badges", bs3_specific: true, phlex_target: "Components::Badge", bs4_replacement: "badge badge-success" },
  "label-info" => { category: "Badges", bs3_specific: true, phlex_target: "Components::Badge", bs4_replacement: "badge badge-info" },
  "label-warning" => { category: "Badges", bs3_specific: true, phlex_target: "Components::Badge", bs4_replacement: "badge badge-warning" },
  "label-danger" => { category: "Badges", bs3_specific: true, phlex_target: "Components::Badge", bs4_replacement: "badge badge-danger" },
  "badge" => { category: "Badges", bs3_specific: false, phlex_target: "Components::Badge" },

  # Tables
  "table" => { category: "Tables", bs3_specific: false, phlex_target: "Components::Table" },
  "table-striped" => { category: "Tables", bs3_specific: false, phlex_target: "Components::Table" },
  "table-bordered" => { category: "Tables", bs3_specific: false, phlex_target: "Components::Table" },
  "table-hover" => { category: "Tables", bs3_specific: false, phlex_target: "Components::Table" },
  "table-condensed" => { category: "Tables", bs3_specific: true, phlex_target: "Components::Table", bs4_replacement: "table-sm" },
  "table-responsive" => { category: "Tables", bs3_specific: false, phlex_target: "Components::Table" },

  # Modals
  "modal" => { category: "Modals", bs3_specific: false, phlex_target: "Components::Modal" },
  "modal-dialog" => { category: "Modals", bs3_specific: false, phlex_target: "Components::Modal" },
  "modal-content" => { category: "Modals", bs3_specific: false, phlex_target: "Components::Modal" },
  "modal-header" => { category: "Modals", bs3_specific: false, phlex_target: "Components::Modal" },
  "modal-body" => { category: "Modals", bs3_specific: false, phlex_target: "Components::Modal" },
  "modal-footer" => { category: "Modals", bs3_specific: false, phlex_target: "Components::Modal" },

  # Dropdowns
  "dropdown" => { category: "Dropdowns", bs3_specific: false, phlex_target: "Components::Dropdown" },
  "dropdown-menu" => { category: "Dropdowns", bs3_specific: false, phlex_target: "Components::Dropdown" },
  "dropdown-toggle" => { category: "Dropdowns", bs3_specific: false, phlex_target: "Components::Dropdown" },

  # Utilities
  "pull-left" => { category: "Utilities", bs3_specific: true, phlex_target: "N/A", bs4_replacement: "float-left" },
  "pull-right" => { category: "Utilities", bs3_specific: true, phlex_target: "N/A", bs4_replacement: "float-right" },
  "hidden-xs" => { category: "Utilities", bs3_specific: true, phlex_target: "N/A", bs4_replacement: "d-none d-sm-block" },
  "hidden-sm" => { category: "Utilities", bs3_specific: true, phlex_target: "N/A", bs4_replacement: "d-none d-md-block" },
  "visible-xs" => { category: "Utilities", bs3_specific: true, phlex_target: "N/A", bs4_replacement: "d-block d-sm-none" },
  "visible-sm" => { category: "Utilities", bs3_specific: true, phlex_target: "N/A", bs4_replacement: "d-none d-sm-block d-md-none" },
  "text-muted" => { category: "Utilities", bs3_specific: false, phlex_target: "N/A" },
  "text-primary" => { category: "Utilities", bs3_specific: false, phlex_target: "N/A" },
  "text-center" => { category: "Utilities", bs3_specific: false, phlex_target: "N/A" },
  "text-right" => { category: "Utilities", bs3_specific: false, phlex_target: "N/A" },
  "text-left" => { category: "Utilities", bs3_specific: false, phlex_target: "N/A" },

  # Wells (removed in BS4)
  "well" => { category: "Wells", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card bg-light" },
  "well-sm" => { category: "Wells", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card bg-light p-2" },
  "well-lg" => { category: "Wells", bs3_specific: true, phlex_target: "Components::Card", bs4_replacement: "card bg-light p-4" }
}.freeze

class BootstrapAuditor
  attr_reader :view_dir, :results, :file_usage

  def initialize
    @view_dir = Pathname.new("app/views")
    @results = Hash.new(0)
    @file_usage = Hash.new { |h, k| h[k] = Hash.new(0) }
    @view_to_component_map = {}
  end

  def run
    puts "=" * 80
    puts "BOOTSTRAP USAGE AUDIT"
    puts "=" * 80
    puts

    scan_all_views
    generate_reports
  end

  private

  def scan_all_views
    puts "Scanning #{view_dir}..."
    puts

    view_files = Dir.glob("#{view_dir}/**/*.{erb,html,html.erb}")

    view_files.each do |file|
      scan_file(file)
    end

    puts "Scanned #{view_files.count} files"
    puts
  end

  def scan_file(file_path)
    content = File.read(file_path)
    relative_path = Pathname.new(file_path).relative_path_from(Pathname.new(".")).to_s

    BOOTSTRAP_COMPONENTS.each_key do |pattern|
      # Match class="..." or class='...' with the pattern
      matches = content.scan(/class=["'][^"']*\b#{Regexp.escape(pattern)}[^"']*["']/)

      if matches.any?
        @results[pattern] += matches.count
        @file_usage[relative_path][pattern] += matches.count
      end
    end
  end

  def generate_reports
    generate_summary_report
    generate_category_report
    generate_bs3_specific_report
    generate_phlex_migration_priority
    generate_file_hotspots
    generate_component_mapping
  end

  def generate_summary_report
    puts "=" * 80
    puts "SUMMARY"
    puts "=" * 80
    puts
    puts "Total Bootstrap class patterns found: #{@results.keys.count}"
    puts "Total Bootstrap class usages: #{@results.values.sum}"
    puts "Total files using Bootstrap: #{@file_usage.keys.count}"
    puts
  end

  def generate_category_report
    puts "=" * 80
    puts "USAGE BY CATEGORY"
    puts "=" * 80
    puts

    by_category = Hash.new(0)
    @results.each do |pattern, count|
      category = BOOTSTRAP_COMPONENTS[pattern][:category]
      by_category[category] += count
    end

    by_category.sort_by { |_, count| -count }.each do |category, count|
      puts "#{category.ljust(20)} #{count.to_s.rjust(6)} usages"
    end
    puts
  end

  def generate_bs3_specific_report
    puts "=" * 80
    puts "BOOTSTRAP 3-SPECIFIC CLASSES (REQUIRE MIGRATION)"
    puts "=" * 80
    puts

    bs3_classes = @results.select do |pattern, _|
      BOOTSTRAP_COMPONENTS[pattern][:bs3_specific]
    end

    if bs3_classes.empty?
      puts "✅ No Bootstrap 3-specific classes found!"
      puts
      return
    end

    puts "Found #{bs3_classes.keys.count} BS3-specific patterns used #{bs3_classes.values.sum} times"
    puts

    bs3_classes.sort_by { |_, count| -count }.each do |pattern, count|
      info = BOOTSTRAP_COMPONENTS[pattern]
      replacement = info[:bs4_replacement] || "N/A"
      puts "⚠️  .#{pattern.ljust(25)} #{count.to_s.rjust(5)}x → #{replacement}"
    end
    puts
  end

  def generate_phlex_migration_priority
    puts "=" * 80
    puts "PHLEX COMPONENT MIGRATION PRIORITY"
    puts "=" * 80
    puts
    puts "Ranked by usage frequency (most-used first)"
    puts

    phlex_components = Hash.new(0)

    @results.each do |pattern, count|
      target = BOOTSTRAP_COMPONENTS[pattern][:phlex_target]
      next if target == "N/A"

      phlex_components[target] += count
    end

    rank = 1
    phlex_components.sort_by { |_, count| -count }.first(20).each do |component, count|
      priority = case rank
                 when 1..5 then "🔴 CRITICAL"
                 when 6..10 then "🟡 HIGH"
                 else "🟢 MEDIUM"
                 end

      puts "#{rank.to_s.rjust(2)}. #{component.ljust(40)} #{count.to_s.rjust(5)}x #{priority}"
      rank += 1
    end
    puts
  end

  def generate_file_hotspots
    puts "=" * 80
    puts "FILE HOTSPOTS (Most Bootstrap-Heavy Files)"
    puts "=" * 80
    puts

    file_totals = @file_usage.transform_values { |classes| classes.values.sum }

    file_totals.sort_by { |_, count| -count }.first(15).each do |file, count|
      puts "#{count.to_s.rjust(4)}x #{file}"
    end
    puts
  end

  def generate_component_mapping
    puts "=" * 80
    puts "ERB VIEW → PHLEX COMPONENT MAPPING RECOMMENDATIONS"
    puts "=" * 80
    puts

    # Identify common patterns and suggest Phlex components
    mappings = analyze_view_patterns

    if mappings.empty?
      puts "No specific view patterns identified for mapping."
      puts
      return
    end

    mappings.each do |view_pattern, recommendation|
      puts "📁 #{view_pattern}"
      puts "   → #{recommendation}"
      puts
    end
  end

  def analyze_view_patterns
    # Group files by directory and identify common patterns
    patterns = {}

    @file_usage.each do |file, classes|
      # Extract directory and file type
      if file.include?("/_")
        # Partial
        dir = File.dirname(file)
        patterns["#{dir}/_*.html.erb (partials)"] ||= suggest_component_for_classes(classes.keys)
      elsif file.include?("/show.html.erb")
        dir = File.dirname(file).split("/").last
        patterns["#{dir}/show.html.erb views"] ||= "Components::#{dir.capitalize}::Show"
      elsif file.include?("/index.html.erb")
        dir = File.dirname(file).split("/").last
        patterns["#{dir}/index.html.erb views"] ||= "Components::#{dir.capitalize}::Index"
      end
    end

    patterns
  end

  def suggest_component_for_classes(class_patterns)
    # Find most common Phlex target
    targets = class_patterns.map do |pattern|
      BOOTSTRAP_COMPONENTS[pattern][:phlex_target]
    end.compact

    most_common = targets.group_by(&:itself).transform_values(&:count).max_by { |_, v| v }
    most_common ? most_common[0] : "Custom Phlex Component"
  end
end

# Run the audit
auditor = BootstrapAuditor.new
auditor.run

puts "=" * 80
puts "NEXT STEPS"
puts "=" * 80
puts
puts "1. Review PHLEX COMPONENT MIGRATION PRIORITY list"
puts "2. Start with CRITICAL priority components (Components::Button, etc.)"
puts "3. Address BOOTSTRAP 3-SPECIFIC classes during Phlex migration"
puts "4. Focus on FILE HOTSPOTS for maximum impact"
puts "5. Use ERB → PHLEX mapping as migration guide"
puts
puts "See: doc/bootstrap-upgrade-plan-for-mo.md - Phase 2"
puts
