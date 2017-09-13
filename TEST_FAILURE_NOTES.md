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
# CHECKBOX FAILURE attribute "persists" after failed save

## commands to run these tests

```
rails t test/controllers/observer_controller_test.rb -n test_project_checkboxes_in_edit_observation
rake test test/controllers/observer_controller_test.rb test_list_checkboxes_in_edit_observation
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
So `edit_observation` again reloads the form
instead of redirecting to the edited Observation.

In master, during 1st call to `post(:edit_observation ...)`
in #edit_observation at its very top:
>
1: request.method = "POST"
2: params = {"observation"=>{"place_name"=>"blah blah blah"}, "project"=>{"id_778455076"=>"1"}, "id"=>"432936842", "controller"=>"observer", "action"=>"edit_observation"}
3: @observation = #<Observation id: 432936842, created_at: "2007-02-27 20:20:00", updated_at: "2007-02-27 20:21:00", when: "2007-02-27", user_id: 241228755, specimen: true, notes: "Second fruiting in bark chips", thumb_image_id: 749502112, name_id: 288002050, location_id: nil, is_collection_location: true, vote_cache: 1.0, num_views: 0, last_view: nil, rss_log_id: nil, lat: nil, long: nil, where: "Glendale, California", alt: nil>
4: @observation.where = "Glendale, California"

During 2nd call to `post(:edit_observation ...)`:
>
1: request.method = "POST"
2: params = {"project"=>{"id_778455076"=>"1"}, "id"=>"432936842", "controller"=>"observer", "action"=>"edit_observation"}
3: @observation = #<Observation id: 432936842, created_at: "2007-02-27 20:20:00", updated_at: "2007-02-27 20:21:00", when: "2007-02-27", user_id: 241228755, specimen: true, notes: "Second fruiting in bark chips", thumb_image_id: 749502112, name_id: 288002050, location_id: nil, is_collection_location: true, vote_cache: 1.0, num_views: 0, last_view: nil, rss_log_id: nil, lat: nil, long: nil, where: "blah blah blah", alt: nil>
4: @observation.where = "blah blah blah"

And @observation remains that way until call to `find_or_go_index`:
>
1: request.method = "POST"
2: params = {"project"=>{"id_778455076"=>"1"}, "id"=>"432936842", "controller"=>"observer", "action"=>"edit_observation"}
3: @observation = #<Observation id: 432936842, created_at: "2007-02-27 20:20:00", updated_at: "2007-02-27 20:21:00", when: "2007-02-27", user_id: 241228755, specimen: true, notes: "Second fruiting in bark chips", thumb_image_id: 749502112, name_id: 288002050, location_id: nil, is_collection_location: true, vote_cache: 1.0, num_views: 0, last_view: nil, rss_log_id: nil, lat: nil, long: nil, where: "Glendale, California", alt: nil>
**4: @observation.where = "Glendale, California"**
>
[244, 253] in /vagrant/mushroom-observer/app/controllers/observer_controller/create_and_edit_observation.rb
```ruby
   244:   def edit_observation # :prefetch: :norobots:
   245:   byebug
   246:     pass_query_params
   247:     includes = [:name, :images, :location]
   248:     @observation = find_or_goto_index(Observation, params[:id].to_s)
=> 249:     return unless @observation
```

But in ror50 @observation does not change after 2nd call to `find_or_go_index`:
>
(byebug) n
1: request.method = "POST"
2: params = <ActionController::Parameters {"project"=>{"id_778455076"=>"1"}, "id"=>"432936842", "controller"=>"observer", "action"=>"edit_observation"} permitted: false>
3: @observation = #<Observation id: 432936842, created_at: "2007-02-27 20:20:00", updated_at: "2017-09-06 20:26:15", when: "2007-02-27", user_id: 241228755, specimen: true, notes: "Second fruiting in bark chips", thumb_image_id: 749502112, name_id: 288002050, location_id: nil, is_collection_location: true, vote_cache: 1.0, num_views: 0, last_view: nil, rss_log_id: nil, lat: nil, long: nil, where: "blah blah blah", alt: nil>
4: **@observation.where = "blah blah blah"**
>
[244, 253] in /vagrant/mushroom-observer/app/controllers/observer_controller/create_and_edit_observation.rb
```ruby
   244:   def edit_observation # :prefetch: :norobots:
   245:   byebug
   246:     pass_query_params
   247:     includes = [:name, :images, :location]
   248:     @observation = find_or_goto_index(Observation, params[:id].to_s)
=> 249:     return unless @observation
```

So in ror50 `find_or_goto_index` returns the attributes from the failed `save`.
Did it actually save these?

Before 1st call to `update_whitelisted_observation_attributes`:
>
@observation.where = "Glendale, California"
Observation.find(432936842).where
["Glendale, California"]

After that call:
>
@observation.where = "blah blah blah
Observation.find(432936842).where
["Glendale, California"]

But after call to `update_projects`
>
@observation.where = "blah blah blah
Observation.find(432936842).where
**["blah blah blah"]**

In that call to `update_projects`, after `project.add_observation(obs)`:
Observation.find(432936842).where
**["blah blah blah"]**

In `project.add_observation(obs)`
after `146:     observations.push(obs)`
Observation.find(432936842).where
**["blah blah blah"]**

Is it also that way in master?
NO

Here's the log for  `146:     observations.push(obs)`
```
   (0.3ms)  SAVEPOINT active_record_1
  User Load (0.6ms)  SELECT  `users`.* FROM `users` WHERE `users`.`id` = 241228755 LIMIT 1
  SQL (0.4ms)  UPDATE `observations` SET `where` = 'blah blah blah', `updated_at` = '2017-09-13 21:12:40' WHERE `observations`.`id` = 432936842
  Interest Load (0.4ms)  SELECT `interests`.* FROM `interests` WHERE `interests`.`target_id` = 432936842 AND `interests`.`target_type` = 'Observation'
  User Load (0.7ms)  SELECT `users`.* FROM `users` WHERE `users`.`email_observations_all` = 1
  SQL (0.6ms)  INSERT INTO `observations_projects` (`observation_id`, `project_id`) VALUES (432936842, 778455076)
   (0.2ms)  RELEASE SAVEPOINT active_record_1
```
What the heck? It's saving the Obs to the db. Why?

