# Thread Safety Analysis for Production Multi-Threading

**Issue:** [#3589](https://github.com/MushroomObserver/mushroom-observer/issues/3589)
**Branch Analyzed:** `njw-parallel-tests`
**Date:** 2025-12-13
**Status:** Analysis Complete

## Executive Summary

Based on the work completed in the `njw-parallel-tests` branch to enable parallel test execution, this report identifies thread safety issues that must be addressed before enabling multi-threaded production deployment. The parallel testing work has uncovered and fixed several critical thread safety patterns that would cause race conditions and data corruption in a multi-threaded production environment.

**Key Finding:** The codebase has made significant progress toward thread safety through the parallel testing work, but additional class variable usage and shared state patterns remain that must be addressed before production multi-threading.

---

## 1. Critical Issues FIXED in Parallel Testing Branch

### 1.1 User Session State (CRITICAL - FIXED ✅)

**Location:** `app/models/user.rb`

**Problem:** The `User.current` mechanism used class variables (`@@user`, `@@location_format`) to store the currently logged-in user. In a multi-threaded environment, all requests would share the same user state, causing catastrophic security issues where User A could see User B's session.

**Before (Thread-Unsafe):**
```ruby
class User
  def self.current
    @@user = nil unless defined?(@@user)
    @@user
  end

  def self.current=(val)
    @@location_format = val ? val.location_format : "postal"
    @@user = val
  end
end
```

**After (Thread-Safe):**
```ruby
class User
  def self.current
    Thread.current[:mushroom_observer_user]
  end

  def self.current=(val)
    Thread.current[:mushroom_observer_user] = val
    Thread.current[:mushroom_observer_location_format] =
      val ? val.location_format : "postal"
  end
end
```

**Impact:** Without this fix, multi-threaded production would have massive security vulnerabilities where users could access each other's sessions.

**Status:** ✅ Fixed with thread-local storage

---

### 1.2 File System Resource Isolation (HIGH - FIXED ✅)

**Location:** `config/consts.rb`, `test/general_extensions.rb`

**Problem:** Multiple threads writing to the same files would cause corruption and race conditions. This affects:
- Image processing directories
- IP blocklist files (`config/blocked_ips.txt`)
- IP stats logs (`log/ip_stats.txt`)
- Job logs (`log/job.log`)
- Locale export directories

**Solution Implemented:**
```ruby
# config/consts.rb - Worker-specific paths
def config.blocked_ips_file
  if env == "test" && (worker_num = IMAGE_CONFIG_DATA.database_worker_number)
    "#{root}/config/blocked_ips-#{worker_num}.txt"
  else
    "#{root}/config/blocked_ips.txt"
  end
end
```

**Production Consideration:** In production with Puma threads, we need a different isolation mechanism since threads share the same process. Options:
- Use thread-safe file locking mechanisms
- Move to database-backed storage for IP stats/blocking
- Use atomic file operations with thread-safe queuing

**Status:** ✅ Fixed for parallel testing (process-based), ⚠️ Needs production strategy (thread-based)

---

### 1.3 Image Processing Isolation (MEDIUM - FIXED ✅)

**Location:** `app/models/image.rb`, `config/consts.rb`

**Problem:** Image processing scripts need to know which image directories to use.

**Solution:**
```ruby
# Pass worker-specific image root
env = { "MO_IMAGE_ROOT" => MO.local_image_files }
output, status = Open3.capture2e(env, "script/strip_exif", id.to_s, ...)
```

**Production Consideration:** In production, all threads share the same image directories, which is correct. The current implementation is production-ready.

**Status:** ✅ Production-ready

---

### 1.4 Job Logging Isolation (LOW - FIXED ✅)

**Location:** `app/jobs/application_job.rb`

**Problem:** Multiple threads writing to the same log file without synchronization.

**Solution for Testing:**
```ruby
def job_log_path
  if Rails.env.test? && (worker_num = IMAGE_CONFIG_DATA.database_worker_number)
    "log/job-#{worker_num}.log"
  else
    "log/job.log"
  end
end
```

**Production Consideration:** Rails logger is already thread-safe. Consider migrating to Rails.logger instead of custom file writing.

**Status:** ✅ Fixed for testing, ⚠️ Consider Rails.logger for production

---

## 2. Remaining Thread Safety Issues

### 2.1 Class Variables Still in Use (HIGH PRIORITY)

**Scope:** 66 occurrences across 8 files

#### 2.1.1 `app/models/user_group.rb` (HIGH - CACHING)

**Issue:** Caches user groups in class variables
```ruby
def self.all_users
  @@all_users ||= get_or_construct_user("all users")
end

def self.one_user(user_id)
  @@one_users ||= {}
  @@one_users[user_id] ||= find_by_name("user #{user_id}")
end
```

**Risk:** Race conditions during cache initialization. Multiple threads could trigger multiple database queries and overwrite each other's cached values.

**Recommended Solution:**
```ruby
# Use Rails.cache with thread-safe operations
def self.all_users
  Rails.cache.fetch("user_group/all_users", expires_in: 1.hour) do
    get_or_construct_user("all users")
  end
end

# Or use Concurrent::Map for in-memory caching
@@one_users = Concurrent::Map.new
def self.one_user(user_id)
  @@one_users.fetch_or_store(user_id) do
    find_by_name("user #{user_id}")
  end
end
```

**Estimated Effort:** 4 hours (refactoring + testing)

---

#### 2.1.2 `app/classes/textile.rb` (MEDIUM - REQUEST-SCOPED STATE)

**Issue:** Stores name lookup state during textile rendering
```ruby
@@name_lookup     = {}
@@last_species    = nil
@@last_subspecies = nil
@@last_variety    = nil
```

**Risk:** If two requests are rendering textile simultaneously, they would corrupt each other's name lookup state, causing incorrect scientific name expansions.

**Recommended Solution:** Convert to instance variables or thread-local storage
```ruby
# Option 1: Instance variables (preferred)
class Textile
  def initialize
    @name_lookup = {}
    @last_species = nil
    # ...
  end
end

# Option 2: Thread-local storage
def self.name_lookup
  Thread.current[:textile_name_lookup] ||= {}
end
```

**Estimated Effort:** 8 hours (requires refactoring call sites)

---

#### 2.1.3 `app/models/language.rb` (LOW - RATE LIMITING)

**Issue:** Timestamp for rate limiting language updates
```ruby
@@last_update = 1.minute.ago
```

**Risk:** Minor race condition on update timestamp. Not critical but could cause unnecessary work.

**Recommended Solution:**
```ruby
# Use Rails.cache with race_condition_ttl
def self.update_language_if_needed
  Rails.cache.fetch("language/last_update", expires_in: 1.minute, race_condition_ttl: 10.seconds) do
    perform_update
    Time.current
  end
end
```

**Estimated Effort:** 2 hours

---

#### 2.1.4 `app/models/location.rb` (LOW - CACHING)

**Issue:** Caches unknown location names
```ruby
@@names_for_unknown ||= official_unknown
```

**Risk:** Minor race condition during initialization. Multiple threads might compute this simultaneously.

**Recommended Solution:**
```ruby
# Use class instance variable with ||= (atomic in MRI but not in JRuby)
@names_for_unknown ||= official_unknown

# Or use Rails.cache
Rails.cache.fetch("location/names_for_unknown", expires_in: 1.day) do
  (official_unknown + :unknown_locations.l.split(/, */)).uniq
end
```

**Estimated Effort:** 2 hours

---

#### 2.1.5 `app/models/language_tracking.rb` (LOW - DEVELOPMENT ONLY)

**Issue:** Tracks language tag usage for development
```ruby
@@tags_used = nil
@@last_clean = nil
```

**Risk:** Low - primarily used in development. Could cause minor issues if used in production.

**Recommended Solution:** Document that this is development-only or make thread-safe with Concurrent::Hash

**Estimated Effort:** 1 hour

---

#### 2.1.6 `app/models/queued_email.rb` (LOW - INITIALIZATION)

**Issue:** Caches email flavors list
```ruby
@@all_flavors = []
```

**Risk:** Minor - only populated during initialization. Race condition during first access.

**Recommended Solution:**
```ruby
# Use class instance variable or freeze the array
@all_flavors ||= begin
  flavors = []
  # populate...
  flavors.freeze
end
```

**Estimated Effort:** 1 hour

---

#### 2.1.7 `app/classes/run_level.rb` (MEDIUM - GLOBAL STATE)

**Issue:** Controls application behavior mode
```ruby
@@runlevel = :normal

def self.normal
  @@runlevel = :normal
end

def self.silent
  @@runlevel = :silent
end
```

**Risk:** If used in production, different threads could have different expectations about system behavior.

**Recommended Solution:**
```ruby
# Thread-local if it should be per-request
def self.runlevel
  Thread.current[:runlevel] || :normal
end

def self.runlevel=(value)
  Thread.current[:runlevel] = value
end

# Or use a frozen constant if it's truly global
RUNLEVEL = :normal
```

**Estimated Effort:** 2 hours + investigation of usage

---

#### 2.1.8 `app/extensions/symbol.rb` (LOW - DEVELOPMENT)

**Issue:** Tracks missing translation tags
```ruby
@@missing_tags = []
```

**Risk:** Low - development/test feature. Could cause minor reporting issues.

**Recommended Solution:** Use Concurrent::Array or document as development-only

**Estimated Effort:** 1 hour

---

### 2.2 Database Connection Pooling

**Status:** Rails handles this automatically ✅

Rails' ActiveRecord connection pool is thread-safe by default. Each thread checks out a connection from the pool, uses it, and returns it. No action required.

**Configuration to verify:**
```yaml
# config/database.yml
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
```

**Recommendation:** Ensure `pool` size matches or exceeds `max_threads` in Puma configuration.

---

### 2.3 External Service Integrations

**Services to audit:**
- Google Cloud Storage (used in `ImageLoaderJob`)
- iNaturalist API (used in `InatImport`)
- Email delivery (ActionMailer)

**Status:** Generally safe ✅

Most HTTP client libraries are thread-safe. However, verify:
- No shared state in client configuration
- Connection pooling is enabled
- Timeout configurations are appropriate

**Estimated Effort:** 4 hours (audit)

---

### 2.4 Session Store

**Current:** Likely cookie-based or database-backed

**Recommendation:**
- Cookie-based: Thread-safe ✅
- Database-backed: Thread-safe ✅
- Redis: Thread-safe if using redis-rb with proper configuration ✅

**Action Required:** Verify session store configuration in `config/initializers/session_store.rb`

**Estimated Effort:** 1 hour (verification)

---

## 3. Puma Configuration for Production

### Recommended Configuration

```ruby
# config/puma.rb

# Workers: multiple processes (handles process crashes, better isolation)
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Threads per worker (this is where thread safety matters)
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Preload app before forking workers (memory efficiency)
preload_app!

# Database connections
before_fork do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# Thread-local cleanup (important!)
on_worker_shutdown do
  # Clean up any thread-local state if necessary
end
```

### Scaling Strategy

**Phase 1: Conservative (Recommended Start)**
- 2 workers × 3 threads = 6 concurrent requests
- Lower thread count reduces thread safety risk
- Test thoroughly in staging

**Phase 2: Moderate**
- 2 workers × 5 threads = 10 concurrent requests
- Monitor for any race conditions

**Phase 3: Aggressive**
- 4 workers × 5 threads = 20 concurrent requests
- Only after confirming thread safety

---

## 4. Testing Strategy

### 4.1 Parallel Test Suite (DONE ✅)

The `njw-parallel-tests` branch already implements comprehensive parallel testing, which exercises many thread safety patterns.

**Current Coverage:**
- User session isolation ✅
- File system isolation ✅
- Database isolation ✅
- Image processing isolation ✅

**Documented in:** `doc/parallel_testing.md`

---

### 4.2 Thread Safety Stress Tests (TODO)

**Recommended:** Create dedicated thread safety integration tests

```ruby
# test/integration/thread_safety_test.rb
class ThreadSafetyStressTest < ActionDispatch::IntegrationTest
  def test_concurrent_user_sessions
    threads = 10.times.map do |i|
      Thread.new do
        user = users("user_#{i}")
        post login_path, params: { credentials }
        get observations_path
        assert_response :success
        assert_equal user.id, session[:user_id]
      end
    end
    threads.each(&:join)
  end

  def test_concurrent_image_uploads
    # Test multiple simultaneous image uploads
  end

  def test_concurrent_observation_edits
    # Test race conditions on observation updates
  end
end
```

**Estimated Effort:** 16 hours (create comprehensive suite)

---

### 4.3 Load Testing with Threads

**Tools:**
- `wrk` - HTTP benchmarking tool
- `artillery` - Load testing framework
- `concurrent-ruby` gem for Ruby-based concurrency tests

**Test Scenarios:**
1. Concurrent logins from different users
2. Simultaneous observation creation
3. Parallel image processing
4. Heavy read traffic with occasional writes

**Estimated Effort:** 8 hours (setup + run + analyze)

---

## 5. Implementation Roadmap

### Phase 1: Critical Fixes (Required before production threading)

**Priority:** CRITICAL
**Timeline:** 2-3 weeks

| Task | File | Estimated Hours | Risk |
|------|------|----------------|------|
| Fix UserGroup caching | `app/models/user_group.rb` | 4 | HIGH |
| Fix Textile name lookup | `app/classes/textile.rb` | 8 | MEDIUM |
| Fix RunLevel state | `app/classes/run_level.rb` | 2 | MEDIUM |
| Create thread safety stress tests | `test/integration/` | 16 | - |
| Code review & audit | All | 8 | - |

**Total: ~38 hours (~1 week)**

---

### Phase 2: Infrastructure & Validation

**Priority:** HIGH
**Timeline:** 1-2 weeks

| Task | Estimated Hours |
|------|----------------|
| Audit external service clients | 4 |
| Verify session store config | 1 |
| Configure Puma for staging | 2 |
| Run load tests in staging | 8 |
| Fix any issues discovered | 16 |
| Documentation | 4 |

**Total: ~35 hours (~1 week)**

---

### Phase 3: Remaining Improvements

**Priority:** MEDIUM
**Timeline:** 1 week

| Task | File | Estimated Hours |
|------|------|----------------|
| Fix Language rate limiting | `app/models/language.rb` | 2 |
| Fix Location caching | `app/models/location.rb` | 2 |
| Fix LanguageTracking | `app/models/language_tracking.rb` | 1 |
| Fix QueuedEmail caching | `app/models/queued_email.rb` | 1 |
| Fix Symbol tracking | `app/extensions/symbol.rb` | 1 |
| Production file logging strategy | `config/consts.rb` | 4 |

**Total: ~11 hours**

---

### Phase 4: Production Rollout

**Priority:** HIGH
**Timeline:** 1-2 weeks

1. **Staging Deployment** (1-2 days)
   - Deploy with conservative threading (2 workers × 2 threads)
   - Monitor for 48 hours
   - Run automated test suite
   - Manual QA testing

2. **Production Canary** (3-5 days)
   - Deploy to 10% of production servers
   - Monitor error rates, response times
   - Watch for thread safety exceptions
   - Collect performance metrics

3. **Full Production Rollout** (2-3 days)
   - Gradual rollout to remaining servers
   - 24/7 monitoring for first week
   - Be prepared to rollback

4. **Optimization** (ongoing)
   - Tune worker/thread counts based on metrics
   - Identify and fix any remaining issues

---

## 6. Monitoring & Observability

### Critical Metrics to Track

**Application Metrics:**
- Request throughput (requests/second)
- Response times (p50, p95, p99)
- Error rates (overall and by endpoint)
- Thread pool utilization
- Database connection pool usage

**System Metrics:**
- CPU utilization
- Memory usage (watch for memory leaks)
- Garbage collection frequency
- Process count

**Thread Safety Indicators:**
- Exceptions related to concurrency (race conditions)
- Unexpected user session switches
- Data corruption incidents
- File I/O errors

### Recommended Tools

```ruby
# Use AppSignal, New Relic, or Skylight for APM

# Add custom instrumentation
ActiveSupport::Notifications.subscribe("thread_pool.puma") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  # Log thread pool stats
end

# Monitor for thread safety issues
ActiveSupport::Notifications.subscribe("thread_safety.warning") do |message|
  # Alert on potential thread safety violations
end
```

---

## 7. Risk Assessment

### Overall Risk Level: MEDIUM-HIGH ⚠️

The parallel testing work has addressed the most critical issues (User.current), but significant work remains.

### Risk Breakdown

| Component | Current Risk | After Phase 1 | Notes |
|-----------|-------------|---------------|-------|
| User Sessions | LOW ✅ | LOW ✅ | Fixed in parallel testing |
| UserGroup Caching | HIGH ⚠️ | LOW ✅ | Needs refactoring |
| Textile Rendering | MEDIUM ⚠️ | LOW ✅ | Needs refactoring |
| File Operations | MEDIUM ⚠️ | MEDIUM ⚠️ | Needs production strategy |
| Database Access | LOW ✅ | LOW ✅ | Rails handles this |
| External Services | MEDIUM ? | LOW ✅ | Needs audit |

### Mitigations

1. **Start Conservative:** Begin with low thread counts
2. **Gradual Rollout:** Use canary deployments
3. **Comprehensive Monitoring:** Catch issues early
4. **Quick Rollback Plan:** Be able to revert quickly
5. **Load Testing:** Stress test in staging first

---

## 8. Success Criteria

Before enabling threading in production, we must achieve:

- [ ] All critical class variable usage refactored
- [ ] Thread safety stress tests passing consistently
- [ ] Staging environment stable with threading for 1 week
- [ ] Load test results show no race conditions
- [ ] Zero thread safety exceptions in staging
- [ ] Monitoring and alerting in place
- [ ] Rollback procedure tested and documented
- [ ] Team training on thread safety patterns completed

---

## 9. Estimated Total Effort

| Phase | Hours | Weeks (1 dev) |
|-------|-------|---------------|
| Phase 1: Critical Fixes | 38 | 1 |
| Phase 2: Infrastructure | 35 | 1 |
| Phase 3: Improvements | 11 | 0.5 |
| Phase 4: Rollout | 40 | 1 |
| **Total** | **124** | **~3.5 weeks** |

**Note:** This assumes one experienced developer. Could be parallelized with 2 developers to ~2 weeks.

---

## 10. Recommendations

### Immediate Actions

1. **Review this analysis** with the team
2. **Prioritize Phase 1 tasks** - these are blockers
3. **Set up staging environment** with Puma threading enabled
4. **Create tracking issue** in GitHub with subtasks

### Short-term (Next Sprint)

1. **Fix critical class variable issues** (UserGroup, Textile)
2. **Build thread safety stress tests**
3. **Begin load testing in staging**

### Medium-term (Next Month)

1. **Complete all Phase 1 & 2 tasks**
2. **Validate in staging for 1-2 weeks**
3. **Plan production rollout**

### Long-term

1. **Monitor production metrics** post-rollout
2. **Optimize thread/worker counts** based on data
3. **Document learnings** for team

---

## 11. Questions & Clarifications Needed

1. **Current production setup:** How many Puma workers? Threads per worker?
2. **Expected traffic increase:** What's driving the need for threading?
3. **Staging environment:** Is it configured identically to production?
4. **Session store:** Confirm current session storage mechanism
5. **Deployment process:** Blue-green? Rolling? Canary support?
6. **Monitoring tools:** What APM/monitoring is currently in use?

---

## 12. References

- **Parallel Testing Branch:** `njw-parallel-tests`
- **Parallel Testing Guide:** `doc/parallel_testing.md`
- **Thread Safety Test:** `test/models/user_thread_safety_test.rb`
- **Rails Threading Guide:** https://guides.rubyonrails.org/threading_and_code_execution.html
- **Puma Documentation:** https://github.com/puma/puma
- **Concurrent Ruby:** https://github.com/ruby-concurrency/concurrent-ruby

---

## Conclusion

The Mushroom Observer codebase has made excellent progress toward thread safety through the parallel testing work. The most critical issue (User.current) has been fixed. However, several class variable usages remain that pose real risks in a multi-threaded production environment.

**The good news:** Most remaining issues are well-understood and have clear solutions. With ~3-4 weeks of focused effort, the application can be made production-ready for multi-threaded deployment.

**Recommendation:** Proceed with Phase 1 (critical fixes) immediately. The parallel testing infrastructure provides an excellent foundation for validating thread safety.
