#!/usr/bin/env ruby
# frozen_string_literal: true

# Theme Validation Script
# Ensures all themes define all required variables and identifies orphaned variables
#
# Usage:
#   script/validate_themes.rb           # Validate all themes
#   script/validate_themes.rb --strict  # Exit with error if any issues found
#
# Exit codes:
#   0 - All themes are valid
#   1 - Missing or orphaned variables found

require "fileutils"

DEFAULTS_FILE = "app/assets/stylesheets/variables/_defaults.scss"
THEMES_DIR = "app/assets/stylesheets/variables"

# Extract all variable names from a SCSS file
def extract_variables_from_file(file_path)
  return [] unless File.exist?(file_path)

  content = File.read(file_path)
  content.scan(/^\$([A-Z_]+):/).flatten.uniq
end

# Get the canonical list of all variables from defaults theme
def load_defaults_variables
  variables = extract_variables_from_file(DEFAULTS_FILE)

  if variables.empty?
    puts "❌ ERROR: Could not find any variables in #{DEFAULTS_FILE}"
    exit(1)
  end

  variables
end

# Find all theme files (excluding defaults)
def find_theme_files
  Dir.glob("#{THEMES_DIR}/_*.scss").reject do |file|
    file.end_with?("_defaults.scss")
  end.sort
end

# Extract theme name from file path
def theme_name_from_path(file_path)
  File.basename(file_path, ".scss").sub(/^_/, "")
end

# Calculate coverage percentage
def coverage_percentage(defined_count, total_count)
  return 0 if total_count.zero?

  ((defined_count.to_f / total_count) * 100).round(1)
end

# Display theme validation results
def display_theme_results(theme_name, theme_vars, defaults_vars)
  missing = defaults_vars - theme_vars
  orphaned = theme_vars - defaults_vars

  puts "#{theme_name}:"
  puts "  ✓ Defines #{theme_vars.size} variables"

  coverage = coverage_percentage(theme_vars.size, defaults_vars.size)
  puts "  📊 Coverage: #{coverage}%"

  if missing.any?
    puts "  ⚠️  Missing #{missing.size} from defaults:"
    missing.sort.each { |var| puts "      - $#{var}" }
  end

  if orphaned.any?
    puts "  ⚠️  Has #{orphaned.size} orphaned variables " \
         "(not in defaults):"
    orphaned.sort.each { |var| puts "      - $#{var}" }
  end

  if missing.empty? && orphaned.empty?
    puts "  ✅ Theme is complete!"
  end

  puts

  { missing: missing, orphaned: orphaned, coverage: coverage }
end

# Validate a single theme file
def validate_theme(theme_file, defaults_vars)
  theme_name = theme_name_from_path(theme_file)
  theme_vars = extract_variables_from_file(theme_file)

  display_theme_results(theme_name, theme_vars, defaults_vars)
end

# Display summary statistics
def display_summary(results, defaults_count)
  puts "=" * 60
  puts "SUMMARY"
  puts "=" * 60

  complete_themes = results.count { |r| r[:missing].empty? && r[:orphaned].empty? }
  total_themes = results.size

  puts "Total themes: #{total_themes}"
  puts "Complete themes: #{complete_themes}"
  puts "Incomplete themes: #{total_themes - complete_themes}"
  puts "Required variables per theme: #{defaults_count}"

  avg_coverage = results.sum { |r| r[:coverage] } / results.size
  puts "Average coverage: #{avg_coverage.round(1)}%"

  puts
end

# Check if validation passed
def validation_passed?(results)
  results.all? { |r| r[:missing].empty? && r[:orphaned].empty? }
end

# Main validation logic
def validate_all_themes(strict_mode: false)
  puts "=" * 60
  puts "THEME VALIDATION"
  puts "=" * 60
  puts

  defaults_vars = load_defaults_variables
  puts "✓ Loaded #{defaults_vars.size} variables from defaults theme"
  puts

  theme_files = find_theme_files

  if theme_files.empty?
    puts "❌ ERROR: No theme files found in #{THEMES_DIR}"
    exit(1)
  end

  puts "Found #{theme_files.size} themes to validate"
  puts

  results = theme_files.map do |theme_file|
    validate_theme(theme_file, defaults_vars)
  end

  display_summary(results, defaults_vars.size)

  if validation_passed?(results)
    puts "✅ All themes are valid!"
    exit(0)
  else
    puts "❌ Validation failed: Some themes have missing or orphaned variables"
    exit(strict_mode ? 1 : 0)
  end
end

# Script entry point
if __FILE__ == $PROGRAM_NAME
  strict_mode = ARGV.include?("--strict")

  if ARGV.include?("--help") || ARGV.include?("-h")
    puts <<~HELP
      Theme Validation Script

      Usage:
        script/validate_themes.rb           # Validate all themes (exit 0)
        script/validate_themes.rb --strict  # Exit with error if issues found
        script/validate_themes.rb --help    # Show this help

      Description:
        Ensures all themes define all required variables from the defaults
        theme and identifies any orphaned variables that don't exist in
        defaults.

      Exit codes:
        0 - All themes are valid (or non-strict mode)
        1 - Missing or orphaned variables found (strict mode only)
    HELP
    exit(0)
  end

  validate_all_themes(strict_mode: strict_mode)
end
