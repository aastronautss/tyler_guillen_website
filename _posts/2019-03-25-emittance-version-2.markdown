---
title: "Emittance, Version 2"
category: programming
summary:
---

Dependency management is one of the key challenges that a developer faces as their software grows in complexity. It’s incredibly easy to introduce a dependency into a class that winds up being difficult to extract after a while.<!-- more --> In a lot of cases, these are two-way entanglements between the caller and the callee.

```ruby
class Thing
  # ...

  def update(params)
    do_stuff_to_self(params)

    SomeMailer.thing_updated(self)
    SearchIndexer.update_index(self)
  end
end
```

In the above (admittedly simple) example, `do_stuff_to_self` is the only part of the workflow that is relevant to what the `#update` method describes. Sending email and updating a search index can all be considered side effects. Furthermore, this method violates the [open-closed principle](https://en.wikipedia.org/wiki/Open%E2%80%93closed_principle), since the side effects will most certainly need to change as the application grows. Furthermore, if we test the `#update` method, we are implicitly testing both `SomeMailer.thing_updated` and `SearchIndexer.update_index`.

One possible way to refactor this is to set a pre-defined list of collaborators and cycle through them.

```ruby
class Thing
  # ...

  UPDATERS = [SomeMailer, SearchIndexer]

  def update(params)
    do_stuff_to_self(params)

    UPDATERS.each { |updater| updater.thing_updated(self) }
  end
end
```

This makes our `#update` method more open-closed. This pattern can take us pretty far, but it still feels a little excessive to keep a list of references to a bunch of different, unrelated interfaces in this class. A `Thing` should ideally have a single, clearly-defined responsibility. However, as the class’s interface evolves, we start to realize that a lot of the bloat we see in the object involves taking care of auxiliary workflows. In the Rails world, the usual route to take is to use ActiveRecord callbacks.

```ruby
class PersistedThing < ApplicationRecord
  UPDATERS = [SomeMailer, SearchIndexer]

  after_update :notify_updaters

  def notify_updaters
    UPDATERS.each { |updater| updater.thing_updated(self) }
  end
end
```

This is a perfectly fine way to implement the pattern we discussed _supra_, but callbacks can easily devolve into a tangled web of dependencies that are difficult to test for and debug.[^1] Furthermore, we still have the same issue in which we must maintain lists of references to extraneous objects.

Another problem with this is that (at least in this case) these collaborators must _also_ have a dependency on the caller. Perhaps our `SearchIndexer` class would implement its `.thing_updated` method like so:

```ruby
class SearchIndexer
  def self.thing_updated(thing)
    send_to_search_api(
      name: thing.name,
      color: thing.color
    )
  end

  # ...
end
```

Again, this is a contrived example. It might be that in this case, we can provide some interface on `Thing` that will allow it to serve as a duck type for this collaboration. Either way, this is still a two-way coupling to at least a small extent, and it seems unnecessary.

These cases are a great example of a problem that the observer pattern was designed to solve. The observer pattern can be thought of as a “publish-subscribe” model of sending messages around an application. Objects (the “publishers”) change throughout the life of our application, and other objects (the “subscribers”) can react to those changes and take actions on their own, without having to wait for the the publishers to tell them what to do. This makes it so the publishers (instances of `Thing`) don’t need to have any sort of dependency on their collaborators (the objects in the `UPDATERS` array). This would turn the two-way dependency into a one-way dependency, and clean up a lot of the cruft in our `Thing` class.

Ruby has a few libraries that provide abstractions that facilitate these interactions, but I wasn’t very happy with their interfaces. I wanted to create an observer pattern library that satisfied at least the following needs:

- Provide a clean interface for publishing and subscribing to messages
- Accommodate flexibility w/r/t exactly _what_ is delivering the published messages

This is why I created Emittance, a library that allows me to treat event-driven architecture exactly how I want to treat it. Emittance’s analogues for publishers and subscribers are “emitters” and “watchers,” respectively.

```ruby
class Thing
  include Emittance::Emitter

  def update(params)
    do_stuff_to_self(params)

    emit('thing_updated', payload: { thing: self, params: params })
  end

  # ...
end

class SearchIndexer
  extend Emittance::Watcher

  def update_index(thing)
    do_stuff_with_hash(thing.to_h)
  end

  # ...
end

SearchIndexer.watch 'thing_updated' do |event| 
  SearchIndexer.update_index(event.payload[:thing])
end

SomeMailer.watch 'thing_updated' do |event|
  SomeMailer.thing_updated(event.payload[:thing])
end
```

Notice how `Thing` no longer contains references to auxiliary stuff. Instead, we just “emit” an event with a payload, and let other classes watch for those events by its identifier. I’m playing around with different ways to make these calls pithier, but in my opinion, it’s much cleaner than how things were before. The `watch` callbacks serve as mini-controllers that format and delegate the event payloads.

## Evolving the design
My ideas for how the pub-sub model works have changed over time[^2], and so when I went to revisit it (about a year after I last touched it) I wanted to align its design to that shift in thought. Version 2.0.0 of the gem brings it closer to these ideas. Here we’ll go over some of the major changes that I made to express those ideas.

### Middleware chains
I’m a big fan of how Sidekiq uses middleware to encapsulate transformations to messages as they are passed from one process to another. With Emittance, I created a simple middleware interface that allows the user to plug in to the event propagation flow and provide their own modifications to the messages that are published. This has been sitting on master for a while, but I decided to bring it to version 2 as an official release.

```ruby
class EventLogger < Emittance::Middleware
  def up(event)
    puts "On hey an event was emitted"

    event
  end

  def down(event)
    puts "Oh hey an event was propagated"

    event
  end
end

Emittance.use_middleware(EventLogger)
```

The `#up` method will be called on the way to the “broker,” and the `#down` method will be called for each watcher to which the event is propagated.

### Honest-to-goodness topics
The thing that grew to bother me the most about the first iteration of Emittance was how I handled building the event objects themselves. When `#emit` is called, an “identifier” is used to determine which subscriptions to propagate the event to. For example, if we wanted to notify the system that a post was published, we would use an identifier such as `post_published`:

```ruby
class Post
  include Emittance::Emitter

  def publish
    do_some
    publishing_stuff

    emit('post_published', payload: { post: self })
  end

  # ...
end
```

Emittance would then go through the following workflow:

1. Look through subclasses of `Emittance::Event` for one whose registered identifiers include `post_published`.
2. If no such subclass exists, create a subclass of `Emittance::Event` whose name is the CamelCase version of the name of the identifier + Event. So, in the above example, `post_published` would convert to `PostPublishedEvent`. Slashes in the identifier’s name would be converted to a namespace. For instance, `post/published` would become `Post::PublishedEvent`.
3. The appropriate subclass would then be instantiated and then passed to its watchers.

I went with this design for a few reasons. First, I imagined a world in which an application would have its own `events` folder, in which each event type has its own set of rules and settings. For example, the class definition for `PostPublishedEvent` could conceivably have a validation to ensure that its payload has an expected set of keys. This was nice in theory, but in practice I found that this just makes a pretty bloated and repetitive bunch of boilerplate we had to maintain. Furthermore, dynamically creating classes is a neat idea (particularly if you caught the meta programming bug as badly as I had at the time), but in retrospect it feels odd to create a bunch of (essentially) identical class objects that just sit there in the object space.

On top of all this, I wanted to provide a way to use RabbitMQ-style topics, so that watchers can set more flexible criteria for the events they want to watch for.

```ruby
SearchIndexer.watch('posts.*') { |event| SearchIndexer.update_index(event.payload[:post]) }

some_post.emit('posts.create', payload: { post: some_post })
# SearchIndexer.update_index is called
```

To implement this, I introduced an additional degree of freedom for configuration with “routing strategies.” This leaves the legacy event class-based strategy intact (though deprecated as of version 2.0.0) while providing an option to swap to the newer topic-based router. Switching to the new strategy is as simple as:

```ruby
Emittance.event_routing_strategy = :topical
```

However, there is a little bit of transitional overhead involved if you’ve invested in the classical routing and lookup strategy. For instance, if you’ve created validations and other macros for the various event classes created by the old system, there may be some additional considerations you’ll want to make, especially if you’re nesting the topic namespace. Since all events are instances of `Emittance::Event` itself, it may be advisable to develop your own middleware to check for valid payloads.

To learn more about how the topical routing works, the [RabbitMQ tutorial](https://www.rabbitmq.com/tutorials/tutorial-five-ruby.html) provides some good examples. Emittance’s topical router is designed to work exactly like RabbitMQ’s topical routing keys.

### Broker selection
In the world of Emittance, a “broker” is an engine used to dispatch events to watchers. It stores the registration data and serializes events as needed. The default broker is the “synchronous” broker, which dispatches all events synchronously, one after another in the thread that emitted the event. Brokers can be created for, e.g., the background job processor of your choice, so that event delivery can be managed using whatever asynchronous strategy you want. Version 1 of Emittance was constrained such that a single broker could be in use at a time (there was always the possibility to swap brokers at runtime, if you took your own thread safety precautions), and I found this to be a limiting factor in the library’s ultimate theme of flexibility.

Say, for instance, wanted to use the observer pattern for a workflow, but we wanted to ensure that it was executed in a particular sequence. If the broker you’re using offloads background jobs to ActiveJob, then this cannot be guaranteed. In version 2, we can set the broker we wish to use on a per-watcher basis.

```ruby
SomethingCritical.watch('orders.charge', broker: :synchronous) do |event|
  SomethingCritical.do_something_with_an_order(event.payload[:order])
end

SomethingLessCritical.watch('orders.charge', broker: :sidekiq, on: :order_bookeeping) do |event|
  SomethingLessCritical.perform_bookkeeping(event.payload[:order])
end
```

In this example, we have a watcher using the `synchronous` broker which, when a relevant event is emitted, will run the callback inline. The other watcher uses the `sidekiq` broker, which will enqueue a job to Sidekiq which will then run the callback.[^3]

Events emitted that match the above identifiers will propagate to all brokers that are “in use.”

## Future plans
As I mentioned briefly _supra_, I’d like to add a few features that make event emission and capture more concise and transparent. There are a few classes in the Emittance library that experiment with those ideas, such as `Action`s and `Notifier`s, but I’m not entirely sure if I’m happy with how they behave.

I would also like to provide a little more flexibility for how topics are treated. RabbitMQ was the starting point, but it would be nice to provide support for, e.g., [MQTT topic formatting](https://www.hivemq.com/blog/mqtt-essentials-part-5-mqtt-topics-best-practices/).

[^1]: Callbacks are probably one of the most contentious topics among Rails developers, and everybody has their own opinions about them. I generally don’t like to use them except to modify values on the model itself (such as setting defaults, computing derived attributes, etc.), but I don’t necessarily see them as a huge anti-pattern _if_ they are used for _auxiliary logic only_.

[^2]: I definitely grew as a programmer in the meantime as well. In a distinct shift in my mental model for what I consider to be Good Design Practices, I’m now much less likely to reach for the metaprogramming tools than I was a year ago.

[^3]: Note the extra `on:` keyword parameter in the call to the Sidekiq broker. This is required in order for look up the callback when the job is dequeued.
