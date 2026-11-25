#!/usr/bin/env ruby
# frozen_string_literal: true

# rubocop:disable MO/NoLongCommentBlock
#
#  USAGE::
#
#    script/recycle_puma_workers.rb            # reports, signals nothing
#    script/recycle_puma_workers.rb --apply    # signals when over the line
#    script/recycle_puma_workers.rb --apply --verbose
#
#  DESCRIPTION::
#
#  Replaces Puma's workers when the host is close to full. A worker's
#  RSS climbs for as long as it lives and glibc hands little back, so
#  six of them plus Solid Queue's seven processes drift up to where a
#  200MB cron script cannot fit: on 2026-11-25 swap went to zero and
#  the kernel killed a Solid Queue worker, taking the site down for
#  four minutes.
#
#  SIGUSR1 is Puma's phased restart: the master replaces one worker at
#  a time, and a worker exits only after the request in its hands
#  finishes. Nothing is dropped, and image resizing (which shells out
#  to `convert` inside the request) runs to completion.
#
#  Boots no Rails -- deciding a memory question should not cost a
#  300MB process -- so it reads /proc directly and is Linux-only.
#
#  Over the line but every worker already young means the restart just
#  happened and something else holds the memory. That prints and
#  signals nothing, which is the interesting alert rather than a loop.
#
# rubocop:enable MO/NoLongCommentBlock

# Reads the host, decides, and says what it did.
class PumaRecycler
  # Percentage of RAM in use, counting reclaimable pages as free,
  # above which the workers are replaced.
  THRESHOLD = Integer(ENV.fetch("PUMA_RECYCLE_PERCENT", 80))

  # A worker younger than this says the last restart is still settling.
  MIN_AGE = Integer(ENV.fetch("PUMA_RECYCLE_MIN_AGE_MINUTES", 30)) * 60

  PIDFILE = File.expand_path("../tmp/pids/puma.pid", __dir__)

  USAGE = "Usage: script/recycle_puma_workers.rb [--apply] [--verbose]"

  # What /proc says about memory, in kB.
  class Meminfo
    def initialize(text)
      @fields = text.lines.to_h do |line|
        key, value = line.split(":")
        [key, value.to_i]
      end
    end

    # MemAvailable is the kernel's estimate of what a new process can
    # have without swapping, which is the question being asked here.
    # MemFree alone would call a healthy page cache an emergency.
    def used_percent
      total = @fields.fetch("MemTotal")
      (total - @fields.fetch("MemAvailable")) * 100.0 / total
    end

    def total_gb = @fields.fetch("MemTotal") / 1_048_576.0

    def used_gb
      (@fields.fetch("MemTotal") - @fields.fetch("MemAvailable")) /
        1_048_576.0
    end

    def swap_used_percent
      total = @fields.fetch("SwapTotal")
      return 0.0 if total.zero?

      (total - @fields.fetch("SwapFree")) * 100.0 / total
    end
  end

  # One Puma worker process, as /proc describes it.
  class Worker
    attr_reader :pid

    def initialize(pid)
      @pid = pid
    end

    def rss_kb
      File.read("/proc/#{pid}/status")[/^VmRSS:\s+(\d+)/, 1].to_i
    end

    # The /proc entry's mtime is when the process started, which saves
    # parsing jiffies out of /proc/<pid>/stat against the boot time.
    def age_seconds = Time.now - File.stat("/proc/#{pid}").mtime
  end

  def initialize(argv)
    @apply = argv.delete("--apply")
    @verbose = argv.delete("--verbose")
    return if argv.empty?

    abort("Unknown argument(s): #{argv.join(" ")}\n#{USAGE}")
  end

  def run
    unless File.readable?("/proc/meminfo")
      abort("No /proc/meminfo: this reads a Linux host, and found none.")
    end

    memory = Meminfo.new(File.read("/proc/meminfo"))
    master = master_pid
    workers = workers_of(master)
    report(memory, master, workers) if @verbose

    return if memory.used_percent < THRESHOLD

    act(memory, master, workers)
  end

  private

  def master_pid
    pid = Integer(File.read(PIDFILE).strip)
    Process.kill(0, pid)
    pid
  rescue Errno::ENOENT, Errno::ESRCH, ArgumentError
    abort("No Puma master running (#{PIDFILE}).")
  end

  # Puma names its worker processes, so the master's children answer
  # for themselves without the master being asked.
  def workers_of(master)
    Dir.glob("/proc/[0-9]*").filter_map do |dir|
      pid = Integer(File.basename(dir))
      next unless File.read("#{dir}/status")[/^PPid:\s+(\d+)/, 1].to_i ==
                  master
      next unless File.read("#{dir}/cmdline").include?("cluster worker")

      Worker.new(pid)
    rescue Errno::ENOENT, Errno::ESRCH
      nil
    end
  end

  def act(memory, master, workers)
    report(memory, master, workers) unless @verbose
    youngest = workers.map(&:age_seconds).min
    return puts(settling(youngest)) if youngest && youngest < MIN_AGE
    return puts(dry_run(master)) unless @apply

    Process.kill("USR1", master)
    puts("Signalled a phased restart (USR1 to #{master}): the workers " \
         "are replaced one at a time, each finishing its request.")
  end

  def dry_run(master)
    "Would signal a phased restart (USR1 to #{master}). " \
      "To apply: script/recycle_puma_workers.rb --apply"
  end

  def settling(youngest)
    "Workers are #{minutes(youngest)} old, under the #{minutes(MIN_AGE)} " \
      "floor: the memory is held by something other than worker creep. " \
      "Signalled nothing."
  end

  def report(memory, master, workers)
    resident = workers.sum(&:rss_kb) / 1_048_576.0
    puts(format("memory %.1f%% used (%.1f of %.1f GB), swap %.1f%% used",
                memory.used_percent, memory.used_gb, memory.total_gb,
                memory.swap_used_percent))
    puts(format("puma master %d, %d workers, %.2f GB resident, " \
                "youngest %s", master, workers.size, resident,
                minutes(workers.map(&:age_seconds).min || 0)))
  end

  def minutes(seconds) = "#{(seconds / 60).round} min"
end

PumaRecycler.new(ARGV.dup).run
