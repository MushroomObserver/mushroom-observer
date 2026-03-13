#!/usr/bin/env ruby
# frozen_string_literal: true

# Verification script for theme system changes
# Run this BEFORE and AFTER Phase 1 changes to detect unintended side effects

require "fileutils"
require "json"

THEMES = %w[
  agaricus
  amanita
  cantharellaceae
  hygrocybe
  admin
  sudo
  black_on_white
  defaults
].freeze

BASELINE_DIR = "test/theme-verification/baseline"
AFTER_DIR = "test/theme-verification/after"

def timestamp
  Time.zone.now.strftime("%Y%m%d_%H%M%S")
end

def create_directory(dir)
  FileUtils.mkdir_p(dir)
  puts("✓ Created directory: #{dir}")
end

def verify_scss_compilation
  puts("\n=== Verifying SCSS Compilation ===")

  THEMES.each do |theme|
    theme_file = "app/assets/stylesheets/variables/_#{theme}.scss"

    if File.exist?(theme_file)
      # Count variables defined
      content = File.read(theme_file)
      variables = content.scan(/^\$([A-Z_]+):/).flatten.uniq

      puts("#{theme.ljust(20)} - #{variables.size} variables defined")
    else
      puts("#{theme.ljust(20)} - FILE NOT FOUND")
    end
  end
end

def extract_variables_from_file(file_path)
  content = File.read(file_path)
  variables = {}

  content.scan(/^\$([A-Z_]+):\s*(.+?);/m).each do |name, value|
    variables[name] = value.strip
  end

  variables
end

def save_theme_variables(theme, variables, output_dir)
  output_file = "#{output_dir}/#{theme}_variables.json"
  File.write(output_file, JSON.pretty_generate(variables))
  puts("✓ Extracted #{variables.size} variables from #{theme}")
end

def extract_variable_definitions(phase = "baseline")
  puts("\n=== Extracting Variable Definitions ===")

  output_dir = phase == "baseline" ? BASELINE_DIR : AFTER_DIR
  create_directory(output_dir)

  THEMES.each do |theme|
    theme_file = "app/assets/stylesheets/variables/_#{theme}.scss"
    next unless File.exist?(theme_file)

    variables = extract_variables_from_file(theme_file)
    save_theme_variables(theme, variables, output_dir)
  end

  puts("\n✓ Variable definitions saved to #{output_dir}/")
end

def checklist_header
  <<~HEADER
    # Theme System Verification Checklist

    Run this checklist AFTER completing Phase 1 changes.

    ## Automated Checks

    - [ ] Run: `script/verify_theme_changes.rb extract after`
    - [ ] Run: `rails assets:precompile RAILS_ENV=production`
    - [ ] Check: No new compilation errors or warnings
  HEADER
end

def checklist_visual_tests
  <<~VISUAL
    ## Manual Visual Verification

    For EACH theme (#{THEMES.join(", ")}):

    ### Homepage (/)
    - [ ] Menu colors are correct
    - [ ] Link colors are correct
    - [ ] Background colors are correct

    ### Observation Index (/observations)
    - [ ] Pager colors are correct
    - [ ] Search form renders correctly
    - [ ] Result cards render correctly

    ### Observation Show (/observations/:id)
    - [ ] Vote meter colors are correct
    - [ ] Button colors are correct
    - [ ] Tooltips appear correctly
    - [ ] Image thumbnails render correctly

    ### Forms (/observations/new or /account/login)
    - [ ] Input field colors are correct
    - [ ] Button hover states work
    - [ ] Error messages display correctly
    - [ ] Help text is readable

    ### User Profile (/users/:id)
    - [ ] Profile card colors are correct
    - [ ] Progress bars (if any) render correctly
    - [ ] Wells/panels render correctly
  VISUAL
end

def checklist_comparison
  <<~COMPARISON
    ## Comparison with Baseline

    - [ ] Compare screenshots side-by-side
    - [ ] Check for any color shifts
    - [ ] Verify no layout changes
    - [ ] Check that hover/active states still work

    ## Variable Comparison

    - [ ] Run: `diff -r test/theme-verification/baseline test/theme-verification/after`
    - [ ] Review any differences - should only be ADDITIONS to defaults
    - [ ] Verify individual themes have NOT changed

    ## Sign-off

    - [ ] All visual checks passed
    - [ ] No compilation errors
    - [ ] Variable changes are as expected
    - [ ] Ready for Phase 2

    Verified by: __________________  Date: __________
  COMPARISON
end

def create_verification_checklist
  checklist = "#{checklist_header}\n#{checklist_visual_tests}\n" \
              "#{checklist_comparison}"

  File.write("test/theme-verification/CHECKLIST.md", checklist)
  puts("✓ Created verification checklist: " \
       "test/theme-verification/CHECKLIST.md")
end

def load_theme_variables(theme, directory)
  file_path = "#{directory}/#{theme}_variables.json"
  return nil unless File.exist?(file_path)

  JSON.parse(File.read(file_path))
end

def compute_variable_changes(baseline, after)
  {
    added: after.keys - baseline.keys,
    removed: baseline.keys - after.keys,
    changed: baseline.keys.select { |k| baseline[k] != after[k] && after[k] }
  }
end

def display_added_variables(added)
  puts("  Added: #{added.size} variables")
  puts("    #{added.join(", ")}") if added.any?
end

def display_removed_variables(removed)
  puts("  Removed: #{removed.size} variables")
  puts("    ⚠️  #{removed.join(", ")}") if removed.any?
end

def display_changed_variables(changed, baseline, after)
  puts("  Changed: #{changed.size} variables")
  return unless changed.any?

  changed.each do |k|
    puts("    ⚠️  #{k}: #{baseline[k]} → #{after[k]}")
  end
end

def display_variable_changes(changes, baseline, after)
  display_added_variables(changes[:added])
  display_removed_variables(changes[:removed])
  display_changed_variables(changes[:changed], baseline, after)
end

def display_warnings(theme, changes)
  if theme != "defaults" && (changes[:removed].any? || changes[:changed].any?)
    puts("  ❌ WARNING: Individual themes should NOT have variables " \
         "removed or changed!")
  elsif theme == "defaults" && changes[:removed].any?
    puts("  ❌ WARNING: Defaults should only have variables ADDED, " \
         "not removed!")
  end
end

def compare_theme_variables(theme)
  baseline = load_theme_variables(theme, BASELINE_DIR)
  after = load_theme_variables(theme, AFTER_DIR)
  return unless baseline && after

  changes = compute_variable_changes(baseline, after)

  puts("\n#{theme}:")
  display_variable_changes(changes, baseline, after)
  display_warnings(theme, changes)
end

def compare_variables
  puts("\n=== Comparing Variables ===")

  unless Dir.exist?(BASELINE_DIR) && Dir.exist?(AFTER_DIR)
    puts("❌ Error: Run 'extract baseline' before changes and " \
         "'extract after' after changes")
    return
  end

  THEMES.each { |theme| compare_theme_variables(theme) }
end

# Main execution
command = ARGV[0]
phase = ARGV[1]

case command
when "extract"
  if phase == "baseline"
    puts("Creating BASELINE snapshot before changes...")
    extract_variable_definitions("baseline")
    create_verification_checklist
  elsif phase == "after"
    puts("Creating AFTER snapshot to compare with baseline...")
    extract_variable_definitions("after")
  else
    puts("Usage: script/verify_theme_changes.rb extract [baseline|after]")
    exit(1)
  end
when "compare"
  compare_variables
when "check"
  verify_scss_compilation
else
  puts(<<~USAGE)
    Theme System Verification Script

    Usage:
      script/verify_theme_changes.rb extract baseline  # Before making changes
      script/verify_theme_changes.rb extract after     # After making changes
      script/verify_theme_changes.rb compare           # Compare baseline vs after
      script/verify_theme_changes.rb check             # Quick SCSS compilation check

    Workflow:
      1. Run 'extract baseline' BEFORE Phase 1 changes
      2. Complete Phase 1 work (add variables to defaults)
      3. Run 'extract after' AFTER Phase 1 changes
      4. Run 'compare' to see differences
      5. Use generated CHECKLIST.md for manual verification
  USAGE
end
