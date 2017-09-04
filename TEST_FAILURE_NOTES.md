This file contains notes about current test Errors and Failures.

TODO: Delete this file when all tests pass.

There are currently a total of 6 Errors/Failures, falling into 3 categories:
- log doesn't update `updated_at`
- undefined path for StringIO
- checkbox failure

# log doesn't update `updated_at`
Here's the code leading to one of these failures.
The failure is at line 187, `assert(rss_log.updated_at > time)`.
```ruby
159   def test_location_rss_log_life_cycle
160     User.current = rolf
161     time = 1.minute.ago
162
163     loc = Location.new(
164       name: "Test Location",
165       north: 54,
166       south: 53,
167       west: -101,
168       east: -100,
169       high: 100,
170       low: 0
171     )
172
173     assert_nil(loc.rss_log)
174     assert_save(loc)
175     loc_id = loc.id
176     assert_not_nil(rss_log = loc.rss_log)
177     assert_equal(:location, rss_log.target_type)
178     assert_equal(loc.id, loc.rss_log.location_id)
179     assert_rss_log_lines(1, rss_log)
180     assert_rss_log_has_tag(:log_location_created_at, rss_log)
181
182     RssLog.update(rss_log.id, updated_at: time)
183     loc.log(:test_message, arg: "val")
184     rss_log.reload
185     assert_rss_log_lines(2, rss_log)
186     assert_rss_log_has_tag(:test_message, rss_log)
187     assert(rss_log.updated_at > time)
```
If I insert a breakpoint at line 182 (i.e., insert `byebug` above line 182),
run the test, and continue (`c`) when I hit the breakpoint, then the assertion
passes. And the test fails at the final (not the next)
`assert(rss_log.updated_at > time)`.

I have no clue what causes this, or where to begin looking.

(Also don't understand why the tests sometimes use `rss_log`
and sometimes `project.rss_log`. It's the same object.
But that has nothing to do with this test failure.)

## commands to run these tests
```
bin/rails test test/models/abstract_model_test.rb:300
bin/rails test test/models/abstract_model_test.rb:159
bin/rails test test/models/abstract_model_test.rb:208
```
## test output
```
  1) Failure:
AbstractModelTest#test_project_rss_log_life_cycle [/vagrant/mushroom-observer/test/models/abstract_model_test.rb:325]:
Expected false to be truthy.

  2) Failure:
AbstractModelTest#test_location_rss_log_life_cycle [/vagrant/mushroom-observer/test/models/abstract_model_test.rb:187]:
Expected false to be truthy.

  3) Failure:
AbstractModelTest#test_name_rss_log_life_cycle [/vagrant/mushroom-observer/test/models/abstract_model_test.rb:240]:
Expected false to be truthy.

```
# undefined path for StringIO

Error 4 is perhaps a Rails / actionpack / rack-test bug.
Is there a work-around, i.e., Can we modify the MO test?
I'm not sure of the intent of the test.

## command to run this test
```
bin/rails test test/controllers/species_list_controller_test.rb:998
```
## test output
```
4) Error:
SpeciesListControllerTest#test_read_species_list:
NoMethodError: undefined method `path' for #<StringIO:0x0000000ae94cd8>
    /home/vagrant/.rvm/gems/ruby-2.2.3/gems/rack-test-0.6.3/lib/rack/test/uploaded_file.rb:37:in `path'
    /home/vagrant/.rvm/gems/ruby-2.2.3/gems/rack-test-0.6.3/lib/rack/test/utils.rb:134:in `build_file_part'
    /home/vagrant/.rvm/gems/ruby-2.2.3/gems/rack-test-0.6.3/lib/rack/test/utils.rb:104:in `block in get_parts'
    /home/vagrant/.rvm/gems/ruby-2.2.3/gems/rack-test-0.6.3/lib/rack/test/utils.rb:95:in `each'
    /home/vagrant/.rvm/gems/ruby-2.2.3/gems/rack-test-0.6.3/lib/rack/test/utils.rb:95:in `map'
    /home/vagrant/.rvm/gems/ruby-2.2.3/gems/rack-test-0.6.3/lib/rack/test/utils.rb:95:in `get_parts'
    /home/vagrant/.rvm/gems/ruby-2.2.3/gems/rack-test-0.6.3/lib/rack/test/utils.rb:91:in `build_parts'
    /home/vagrant/.rvm/gems/ruby-2.2.3/gems/rack-test-0.6.3/lib/rack/test/utils.rb:81:in `build_multipart'
    /home/vagrant/.rvm/gems/ruby-2.2.3/gems/actionpack-5.0.5/lib/action_controller/test_case.rb:91:in `assign_parameters'
    /home/vagrant/.rvm/gems/ruby-2.2.3/gems/actionpack-5.0.5/lib/action_controller/test_case.rb:529:in `process'
    /home/vagrant/.rvm/gems/ruby-2.2.3/gems/rails-controller-testing-1.0.2/lib/rails/controller/testing/template_assertions.rb:61:in `process'
    /home/vagrant/.rvm/gems/ruby-2.2.3/gems/actionpack-5.0.5/lib/action_controller/test_case.rb:649:in `process_with_kwargs'
    /home/vagrant/.rvm/gems/ruby-2.2.3/gems/actionpack-5.0.5/lib/action_controller/test_case.rb:397:in `post'
    /vagrant/mushroom-observer/test/functional_test_case.rb:30:in `post'
    /vagrant/mushroom-observer/test/controller_extensions.rb:435:in `assert_request'
    /vagrant/mushroom-observer/test/controller_extensions.rb:212:in `either_requires_either'
    /vagrant/mushroom-observer/test/controller_extensions.rb:143:in `post_requires_login'
    /vagrant/mushroom-observer/test/controllers/species_list_controller_test.rb:1011:in `test_read_species_list'
```
# checkbox failure

I don't understand why the following fail.

## commands to run these tests

```
rails t test/controllers/observer_controller_test.rb -n test_project_checkboxes_in_edit_observation
rails t test/controllers/observer_controller_test.rb -n test_list_checkboxes_in_edit_observation
```
## test output

```
$ bin/rails test test/controllers/observer_controller_test.rb -d
...
1) Failure:
ObserverControllerTest#test_list_checkboxes_in_edit_observation [/vagrant/mushroom-observer/test/controllers/observer_controller_test.rb:2441]:


  2) Failure:
ObserverControllerTest#test_project_checkboxes_in_edit_observation [/vagrant/mushroom-observer/test/controllers/observer_controller_test.rb:2345]:


137 runs, 1352 assertions, 2 failures, 0 errors, 0 skips

Failed tests:

bin/rails test test/controllers/observer_controller_test.rb:2428
bin/rails test test/controllers/observer_controller_test.rb:2330
```
Sample; fails at last line
```ruby
  def test_project_checkboxes_in_edit_observation
    init_for_project_checkbox_tests

    # Prove rolf cannot edit mary's Observation
    login("rolf")
    get(:edit_observation, params: { id: @obs1.id })
    assert_response(:redirect)

    # Prove rolf can edit his own Observation,
    # there's an unchecked checkbox for a Project for which he is a member,
    # and no checkbox for a Project for which he is not a member.
    get(:edit_observation, params: { id: @obs2.id })
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)

    # Prove rolf can add his Observation to a Project for which he is a member,
    # leaving checkbox for that Project checked, and
    # no checkbox for Project which he is not a member
    post(:edit_observation,
         params: { id: @obs2.id,
                   # (ensures it will fail)
                   observation: { place_name: "blah blah blah" },
                   project: { "id_#{@proj1.id}" => "1" } })
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)

    # Form is reloaded because "blah blah blah" is not an valid Location
    # Edit again, without changing place_name
    post(:edit_observation,
         params: { id: @obs2.id,
                   project: { "id_#{@proj1.id}" => "1" } })
    assert_redirected_to(action: :show_observation, id: @obs2.id)
```
When it does the 2nd `post(:edit_observation)`, @obs2.where has been changed to
"blah blah blah".  (This is not the case in master.)
So the @observation instance variable is persisted between requests!
Is this a caching issue?
Is controller itself not reset? (I.e., am I getting the same controller?) Yes, it's same controller, but that's also true in master.
Is it coming from the session?

So `edit_observation` again reloads the form
instead of redirecting to the edited Observation.
