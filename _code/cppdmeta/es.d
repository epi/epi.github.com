import std.stdio;

static if (__traits(compiles, (){ import std.meta; }())) {
  import std.meta : staticIndexOf;
} else {
  import std.typetuple : staticIndexOf;
}

struct EventSystem(events...) {
  alias Callback = void delegate();
  Callback[][events.length] callbacks_;

  void on(string event)(Callback c) {
    enum index = staticIndexOf!(event, events);
    static assert(index >= 0,
      "trying to add a callback to an unknown event: " ~ event);

    callbacks_[index] ~= c;
  }

  void trigger(string event)() {
    enum index = staticIndexOf!(event, events);
    static assert(index >= 0,
      "trying to trigger an unknown event: " ~ event);

    foreach (callback; callbacks_[index])
      callback();
  }

  void trigger(string event) {
    foreach (i, e; events) {
      if (e == event) {
        foreach (c; callbacks_[i])
          c();
        return;
      }
    }
    assert(false, "trying to trigger an unknown event: " ~ event);
  }
}
  
version (Benchmark) {

  void main() {
    import std.datetime : benchmark;
    import std.algorithm : map;

    EventSystem!("foo", "bar", "baz") events;

    shared int ncalls = 0;

    events.on!"foo"((){});
    events.on!"bar"((){});
    events.on!"baz"((){});

    auto foo_fun = (){};
    auto bar_fun = (){};
    auto baz_fun = (){};

    auto n = 100_000_000;
    auto r = benchmark!(
      () {
        events.trigger("foo");
        events.trigger("bar");
        events.trigger("foo");
        events.trigger("bar");
        events.trigger("baz");
      },
      () {
        events.trigger!"foo";
        events.trigger!"bar";
        events.trigger!"foo";
        events.trigger!"bar";
        events.trigger!"baz";
      },
      () {
        foo_fun();
        bar_fun();
        foo_fun();
        bar_fun();
        baz_fun();
      })(n);

      writefln("%(%s%| %)", r[].map!(a => a.nsecs / (n * 5.0)));
  }

} else {

  void main() {
    EventSystem!("foo", "bar", "baz") events;

    events.on!"foo"(() { writeln("foo triggered!"); });
    events.on!"foo"(() { writeln("foo again!"); });
    events.on!"bar"(() { writeln("bar triggered!"); });
    events.on!"baz"(() { writeln("baz triggered!"); });
    //events.on!"unknown"(() {}); // compile error!

    events.trigger!"foo";
    events.trigger!"baz";
    events.trigger("bar"); // dynamic dispatch
    // events.trigger("bat"); // run-time error
    // events.trigger!"unknown"; // compile error!
  }

}
