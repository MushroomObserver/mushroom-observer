# frozen_string_literal: true

module Views::Controllers::Images
  # Admin/test page listing the most-recent test-upload entries.
  # Driven by `script/perf_monitor`. Converted from
  # `images/test_add_image_report.html.erb`.
  class TestAddImageReport < Views::Base
    # Upload-log model lives outside MO core; entries are duck-typed
    # here (respond to `id` / `user` / `created_at` / `upload_end` /
    # `image_count` / `image_bytes`).
    prop :log_entries, _Array(::Object)

    def view_template
      add_page_title("Test Add Image Report")
      add_context_nav(::Tab::Image::TestAgain.new)

      render(::Components::Table.new(
               @log_entries, class: "table-striped table-upload-report"
             )) { |t| build_columns(t) }
    end

    private

    def build_columns(table)
      table.column("Id", &:id)
      table.column("User") { |e| e.user ? e.user.login : "" }
      table.column("Start") { |e| e.created_at.web_time }
      table.column("End") { |e| e.upload_end.web_time }
      table.column("Elapsed") { |e| elapsed_for(e) }
      table.column("Count", &:image_count)
      table.column("Bytes", &:image_bytes)
    end

    def elapsed_for(entry)
      return "" unless entry.created_at && entry.upload_end

      entry.upload_end - entry.created_at
    end
  end
end
