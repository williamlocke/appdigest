Appdigest
=========

Purchase analytics using AppFigures API.


Installation
------------

~~~ sh
$ git clone git@github.com:williamlocke/appdigest.git
$ cd appdigest
$ sudo rake install
~~~

Set environmental variables for appfigures:
~~~ sh
export APPFIGURES_USERNAME=user@example.com
export APPFIGURES_PASSWORD=password
~~~


Usage
-----

Search and provide totals/averages for in-app purchases that contain given keywords (csv)
~~~ sh
$ appdigest search characters,patients,babies
~~~

Compare app performance firt week
~~~ sh
$ appdigest search "*" --type app --week
~~~

Compare app performance firt 3 days
~~~ sh
$ appdigest search "*" --type app --days 3
~~~

View recent revenue (past weeks)
~~~ sh
$ appdigest recent --week
~~~

View recent revenue (past 3 days)
~~~ sh
$ appdigest recent --days 3
~~~


Help
----

View available commands
~~~ sh
$ appdigest 
~~~

View available options for a particular command
~~~ sh
$ appdigest help search
~~~




Contributing to appdigest
-------------------------
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

