#!/usr/bin/env ruby
# frozen_string_literal: true

# rubocop:disable MO/NoLongCommentBlock
#
#  USAGE::
#
#    script/recycle_puma_workers.rb            # reports, changes nothing
#    script/recycle_puma_workers.rb --apply    # acts when over the line
#    script/recycle_puma_workers.rb --apply --verbose
#
#  DESCRIPTION::
#
#  Replaces a Puma worker when the host is close to full. A worker's
#  RSS climbs for as long as it lives and glibc hands little back, so
#  six of them plus Solid Queue's seven processes drift up to where a
#  200MB cron script cannot fit: on 2026-11-25 swap went to zero and
#  the kernel killed a Solid Queue worker, taking the site down for
#  four minutes.
#
#  One worker per run, the largest. SIGTERM to a worker is a graceful
#  stop: it finishes the request in its hands, reports to the master
#  over its status pipe that the stop came from outside, and the
#  master forks a replacement from the preloaded app in a fraction of
#  a second. Six runs of the ten-minute cron line reach all six
#  workers, so the staggering costs nothing to arrange.
#
#  Not SIGUSR1 to the master. That asks for a phased restart, which
#  Puma refuses while the app is preloaded -- and Puma 8 preloads by
#  default above one worker. The signal falls through to a hot restart
#  instead: the master re-execs and every worker goes down together.
#
#  Boots no Rails -- deciding a memory question should not cost a
#  300MB process -- so it reads /proc directly and is Linux-only.
#
#  Over the line with every worker young means the last replacement
#  just happened and something else holds the memory. That prints and
#  changes nothing, which is the interesting alert rather than a loop.
#
# rubocop:enable MO/NoLongCommentBlock

# Reads the host, decides, and says what it did.
class PumaRecycler
  # Percentage of RAM in use, counting reclaimable pages as free,
  # above which a worker is replaced.
  THRESHOLD = Integer(ENV.fetch("PUMA_RECYCLE_PERCENT", 80))

  # A worker younger than this is left alone: it is either a
  # replacement from a recent run or too new to have grown.
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

  # One Puma worker process, as /proc describes it. Both readings are
  # taken once, so a worker that exits between the decision and the
  # signal does not change shape underneath the message.
  class Worker
    attr_reader :pid

    def initialize(pid)
      @pid = pid
    end

    def rss_kb
      @rss_kb ||= File.read("/proc/#{pid}/status")[/^VmRSS:\s+(\d+)/, 1].to_i
    rescue Errno::ENOENT
      0
    end

    # The /proc entry's mtime is when the process started, which saves
    # parsing jiffies out of /proc/<pid>/stat against the boot time.
    def age_seconds
      @age_seconds ||= Time.now - File.stat("/proc/#{pid}").mtime
    rescue Errno::ENOENT
      0
    end
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
    abort("No Puma workers under master #{master}.") if workers.empty?
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
    target = target_worker(workers)
    return puts(settling(workers)) unless target
    return puts(dry_run(target)) unless @apply

    signal(target)
  end

  # The largest worker old enough to have done its growing. Replacing
  # the largest returns the most memory per request interrupted.
  def target_worker(workers)
    workers.select { |worker| worker.age_seconds >= MIN_AGE }.
      max_by(&:rss_kb)
  end

  def signal(target)
    Process.kill("TERM", target.pid)
    puts("Sent SIGTERM to worker #{describe(target)}: it stops claiming " \
         "requests, finishes the one in its hands, and the master forks " \
         "a replacement.")
  rescue Errno::ESRCH
    puts("Worker #{target.pid} exited before the signal reached it. " \
         "The next run picks whichever has grown most by then.")
  end

  def dry_run(target)
    "Would replace worker #{describe(target)}. " \
      "To apply: script/recycle_puma_workers.rb --apply"
  end

  def describe(worker)
    format("%d (%d MB, %s old)", worker.pid, worker.rss_kb / 1024,
           minutes(worker.age_seconds))
  end

  def settling(workers)
    "The workers are #{minutes(workers.map(&:age_seconds).min)} old, " \
      "under the #{minutes(MIN_AGE)} floor: the memory is held by " \
      "something other than worker creep. Changed nothing."
  end

  def report(memory, master, workers)
    resident = workers.sum(&:rss_kb) / 1_048_576.0
    puts(format("memory %.1f%% used (%.1f of %.1f GB), swap %.1f%% used",
                memory.used_percent, memory.used_gb, memory.total_gb,
                memory.swap_used_percent))
    puts(format("puma master %d, %d workers, %.2f GB resident, " \
                "youngest %s", master, workers.size, resident,
                minutes(workers.map(&:age_seconds).min)))
  end

  def minutes(seconds) = "#{(seconds / 60).round} min"
end

PumaRecycler.new(ARGV.dup).run
