# SSDB::Attr - Intuitively manage attributes of your model in SSDB.


This gem provides a Rubyish interface to save values to SSDB in your `ActiveModel` object.

It offers several advantages:

1. Easy to integrate directly with `ActiveModel`, means it could be used with your existing Rails proejct right away.
2. Complex data structures are supported. (Now only `SortedSet` is supported and more is on the way)
3. Value of `:integer` type is returend as integer, ranther than '3'

### Installation

Add it to your Gemfile as:

```ruby
gem 'ssdb-attr'
```

### Setup

First you need to setup connections to SSDB:

```ruby
SSDBAttr.setup(:url => "redis://localhost:8888")
```

`SSDB::Attr` uses `ConnectionPool` to manage connections to SSDB, so you could specify pool size and timeout like following:

```ruby
SSDBAttr.setup(:url => "redis://localhost:8888", pool: 25, timeout: 2)
```

If you use it in your Rails project, you could setup it in one of your initializers:

```ruby
# config/initializers/ssdb-attr.rb
SSDBAttr.setup(:url => "redis://localhost:8888", pool: 25, timeout: 2)
```

### Usage

First you need to include it into on of your model, and define the attributes:

```ruby
class Post < ActiveRecord::Base
  include SSDB::Attr

  ssdb_attr :int_val,           :integer
  ssdb_attr :int_with_default,  :integer, :default => 100
  ssdb_attr :str_val,           :string
  ssdb_attr :str_with_default,  :string,  :default => 'foo'
  ssdb_attr :bool_val,          :boolean
  ssdb_attr :bool_with_default, :boolean, :default => false
  ssdb_attr :test_set,          :sorted_set
end
```

#### Integer

```ruby
> @post = Post.new
 => #<Post id: nil, updated_at: nil, saved_at: nil, changed_at: nil>
> @post.int_val
 => nil
> @post.int_with_default
 => 100
> @post.int_val = 2000
 => 2000
> @post.int_val
 => 2000
```

#### String

```ruby
> @post.str_val
 => nil
> @post.str_with_default
 => "foo"
> @post.str_val = "bar"
 => "bar"
> @post.str_val
 => "bar"
```

#### Boolean

```ruby
> @post.bool_val
 => nil
> @post.bool_with_default
 => false
> @post.bool_val = true
 => true
> @post.bool_val
 => true
```

#### SortedSet

```ruby
> @post.test_set.count                # initially there's no item in the set
 => 0
> @post.test_set.add(:bar1, 1)        # add `bar1` with score 1
 => "OK"
> @post.test_set.add(:bar2, 2)        # add `bar2` with score 2
 => "OK"
> @post.test_set.add(:bar3, 3)        # add `bar3` with score 3
 => "OK"
> @post.test_set.count                # now we have 3 items in the set
 => 3
> @post.test_set.score(:bar1)         # get the score of `bar1`
 => 1.0
> @post.test_set.incr(:bar1, 10)      # increase the score of `bar1` by 10
 => "OK"
> @post.test_set.score(:bar1)         # get the score of `bar1`, now it's 11
 => 11.0
> @post.test_set.all                  # return all the keys in array, sorted by scores asc.
 => ["bar2", "bar3", "bar1"]
> @post.test_set.rebuild_with(['foo1', 'foo2', 'foo3'])     # clear whole set and rebuild with an array, the score is automatically set to the index of the item in the array
 => ["foo1", "foo2", "foo3"]
> @post.test_set.all                  # now it's `foo1` `foo2` `foo3` in the set
 => ["foo1", "foo2", "foo3"]
> @post.test_set.score('foo1')        # score of `foo1` is 0
 => 0.0
> @post.test_set.score('foo2')        # score of `foo2` is 1
 => 1.0
> @post.test_set.score('foo3')        # score of `foo3` is 2
 => 2.0
> @post.test_set.clear                # clear all
 => "OK"
> @post.test_set.count                # nothing in the set now
 => 0
```

#### Update multiple attrs at the same time

We provide a method like `update` in `ActiveRecord` to update `ssdb:attr` with a hash.
This method only works with attrs of `string`, `integer` and `boolean` type.

If an attr of `:sorted_set` type is passed, it will be ignored.

```ruby
> @post.update_ssdb_attrs(:str_val => 'the good era', :int_val => 30)  # now `update_ssdb_attrs`
 => true
> @post.str_val
 => "the good era"
2.3.0 :049 > @post.int_val
 => 30
```

`update_ssdb_attrs` method also provide callbacks enabled by `ActiveModel`.

You could define callbacks like:

```ruby
class Post
  ...

  before_update_ssdb_attrs :before_callback

  after_update_ssdb_attrs  :after_callback


  def before_callback
    if int_val_changed?
      puts "int_val changed in before_callback"
    end

    if str_val_changed?
      puts "str_val changed in before_callback"
    end

    if bool_val_changed?
      puts "bool_val changed in before_callback"
    end
  end

  def after_callback
    if int_val_changed?
      puts "int_val changed in after_callback"
    end

    if str_val_changed?
      puts "str_val changed in after_callback"
    end

    if bool_val_changed?
      puts "bool_val changed in after_callback"
    end
  end

  ...
end

```

And with this if you update two attrs, you could see the `callbacks` responding and the dirty field check working.

```ruby
> @post.int_val = 10
 => 10
> @post.str_val = :foobar
 => :foobar
> @post.bool_val = true
 => true
> @post.update_ssdb_attrs(:str_val => 'hello world', :int_val => 20)
int_val changed in before_callback
str_val changed in before_callback
int_val changed in after_callback
str_val changed in after_callback
 => true # currently this method always returns true.
```

### Disconnecting

You could call `SSDBAttr.disconnect!` to close all the connections that `SSDBAttr` holds.
