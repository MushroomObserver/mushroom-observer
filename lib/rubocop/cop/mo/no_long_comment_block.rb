# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Flags a run of more than `Max` consecutive full-line comments
      # (a trailing `# comment` on a code line doesn't count). A long
      # comment is narrative -- it belongs in the commit message or
      # PR description, not baked into the source. See
      # .claude/rules/code_comments.md.
      #
      # A comment load-bearing at that length can be kept with an
      # inline `rubocop:disable`/`:enable` pair explaining why -- this
      # cop has no built-in exception for that case, by design.
      #
      # A run directly above a `class`/`module` keyword is exempt --
      # that's a documentation block, not inline narrative -- but
      # still proofread and shorten it by hand; the exemption isn't
      # permission to leave it bloated.
      #
      # @example Max: 15 (project default)
      #   # bad -- 16+ consecutive comment lines
      #   # one
      #   # ...
      #   # sixteen
      #   def foo; end
      #
      #   # good
      #   # one
      #   # two
      #   def foo; end
      class NoLongCommentBlock < Base
        MSG = "Comment block of %<count>d consecutive lines (max " \
              "%<max>d) -- cut to the single load-bearing fact; " \
              "narrative belongs in the commit message or PR " \
              "description."

        def on_new_investigation
          max = cop_config.fetch("Max", 5)
          each_full_line_comment_run do |run|
            next if run.size <= max
            next if class_or_module_doc?(run)

            add_offense(
              offense_range(run),
              message: format(MSG, count: run.size, max: max)
            )
          end
        end

        private

        # Yields each run of consecutive full-line comments (an Array
        # of Parser::Source::Comment) as they occur in the file.
        def each_full_line_comment_run
          run = []
          processed_source.comments.each do |comment|
            if full_line_comment?(comment) && continues_run?(run, comment)
              run << comment
              next
            end

            yield(run) if run.any?
            run = full_line_comment?(comment) ? [comment] : []
          end
          yield(run) if run.any?
        end

        def continues_run?(run, comment)
          run.any? && comment.loc.line == run.last.loc.line + 1
        end

        # A comment that is the only thing on its line, not a
        # trailing `code # comment`.
        def full_line_comment?(comment)
          line = processed_source.lines[comment.loc.line - 1]
          line.to_s[0...comment.loc.column].strip.empty?
        end

        # A run directly above a `class`/`module` keyword -- allowing
        # a single blank separator line, the common RDoc-header style
        # in this codebase -- is a documentation block, not inline
        # narrative.
        def class_or_module_doc?(run)
          line_index = run.last.loc.line
          line = processed_source.lines[line_index].to_s
          if line.strip.empty?
            line = processed_source.lines[line_index + 1].to_s
          end
          line.match?(/\A\s*(class|module)\b/)
        end

        def offense_range(run)
          Parser::Source::Range.new(
            processed_source.buffer,
            run.first.loc.expression.begin_pos,
            run.last.loc.expression.end_pos
          )
        end
      end
    end
  end
end
