import std.stdio;
import std.algorithm : min;

static if (__traits(compiles, (){ import std.meta; }())) {
  import std.meta : staticIndexOf, staticMap, AliasSeq;
} else {
  import std.typetuple : staticIndexOf, staticMap, AliasSeq = TypeTuple;
}

struct Entity(arg...)
  if (arg.length == 1)
{
  static if (is(arg[0])) {
    alias Type = arg[0];
  } else static if (is(typeof(arg[0]) T)) {
    alias Type = T;
    enum value = arg[0];
  }
}

enum c(arg...) = Entity!arg();

unittest {
  static assert(is(c!int.Type == int));
  static assert(is(c!"foo".Type == string));
  static assert(c!"foo".value == "foo");
  static assert(c!42.value == 42);
}

template Stride(size_t first, size_t stride, A...) {
  static if (A.length > first)
    alias Stride = AliasSeq!(A[first], Stride!(stride, stride, A[first .. $]));
  else
    alias Stride = AliasSeq!();
}

alias Odd(A...) = Stride!(1, 2, A);
alias Even(A...) = Stride!(0, 2, A);

unittest {
  static struct Id(A...) {};
  static assert(is(Id!(Even!(0, 1, 2, 3, 4, 5)) == Id!(0, 2, 4)));
  static assert(is(Id!(Odd!(0, 1, 2, 3, 4, 5)) == Id!(1, 3, 5)));
}

struct Map(spec...)
  if (spec.length >= 2 && spec.length % 2 == 0)
{
  alias Keys = Even!spec;
  alias Values = Odd!spec;
  Values values;

  private template IndexOf(alias Key) {
    enum IndexOf = staticIndexOf!(Key, Keys);
    static assert(IndexOf >= 0,
      "trying to access nonexistent key: " ~ Key);
  }

  auto opIndex(Key...)(Entity!Key key) const {
    return values[IndexOf!Key];
  }

  auto opIndexAssign(T, Key...)(auto ref T value, Entity!Key key) {
    return values[IndexOf!Key] = value;
  }

  auto opIndexOpAssign(string op, T, Key...)(auto ref T value, Entity!Key key) {
    return mixin(`values[IndexOf!Key] ` ~ op ~ `= value`);
  }

  static bool opBinaryRight(string op, Key...)(Entity!Key key) pure nothrow
    if (op == "in")
  {
    enum index = staticIndexOf!(Key, Keys);
    return index >= 0;
  }
}

unittest {
  struct Bar {}

  auto map = Map!(
    "foo", int,
    Bar, string,
    "한", string[])(42, "baz", ["lorem", "ipsum" ]);

  assert(map[c!"foo"] == 42);  // opIndex
  assert(map[c!Bar] == "baz");
  assert(map[c!"한"] == ["lorem", "ipsum"]);

  static assert(c!"foo" in map);  // opBinaryRight
  static assert(c!Bar in map);
  static assert(c!"한" in map);
  static assert(c!42 !in map);

  map[c!"foo"] = -1;        // opIndexAssign
  map[c!Bar] = "bar";
  map[c!"한"] ~= "dolor";

  assert(map[c!"foo"] == -1);  // opIndex
  assert(map[c!Bar] == "bar");
  assert(map[c!"한"] == ["lorem", "ipsum", "dolor"]);

  // iterate over keys
  foreach (key; map.Keys)
    writefln("%s: %s", key.stringof, map[c!key]);

  // iterate over types of values
  foreach (V; map.Values)
    writeln(V.stringof);

  // iterate over values
  foreach (value; map.values)
    writeln(value);
}

struct EventSystem(events...) {
  alias Callback = void delegate();
  alias mapToCallbackVector(A...) = AliasSeq!(A, Callback[]);
  Map!(staticMap!(mapToCallbackVector, events)) map_;
  Callback[]*[string] dynamic_;

  @disable this();

  void on(Event)(Event e, Callback callback) {
    static assert(e.init in map_,
      "trying to add a callback to an unknown event");

    map_[e] ~= callback;
  }

  void on(string event)(Callback callback) {
    static assert(c!event in map_,
      "trying to add a callback to an unknown event");

    map_[c!event] ~= callback;
  }

  // supports trigger(c!"event") syntax (compile-time dispatch)
  void trigger(Event)(Event e) const {
    static assert(e.init in map_,
      "trying to trigger an unknown event");

    foreach (callback; map_[e])
      callback();
  }

  // supports trigger!"event" syntax (compile-time dispatch)
  void trigger(string event)() {
    static assert(c!event in map_,
      "trying to trigger an unknown event");

    foreach (callback; map_[c!event])
      callback();
  }

  // supports trigger("event") syntax (run-time dispatch, AA)
  void trigger(string event) {
    auto p = event in dynamic_;
    assert(p, "trying to trigger an unknown event");
    foreach (c; **p)
      c();
  }
}

auto eventSystem(events...)() {
  auto result = EventSystem!events.init;
  foreach (i, event; result.map_.Keys)
    result.dynamic_[event] = &result.map_.values[i];
  return result;
}

version (Benchmark) {

  void main() {
    import std.datetime : benchmark;
    import std.algorithm : map;

    auto events = eventSystem!("foo", "bar", "baz");

    shared int ncalls = 0;

    events.on!"foo"((){});
    events.on!"bar"((){});
    events.on!"baz"((){});

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
        events.trigger(c!"foo");
        events.trigger(c!"bar");
        events.trigger(c!"foo");
        events.trigger(c!"bar");
        events.trigger(c!"baz");
      },
      () {
        events.trigger!"foo";
        events.trigger!"bar";
        events.trigger!"foo";
        events.trigger!"bar";
        events.trigger!"baz";
      })(n);

    writefln("%(%s%| %)", r[].map!(a => a.nsecs / (n * 5.0)));
  }

} else {

  void main() {
    auto events = eventSystem!("foo", "bar", "baz");

    events.on!"foo"(() { writeln("foo triggered!"); });
    events.on(c!"foo", () { writeln("foo again!"); });
    events.on!"bar"(() { writeln("bar triggered!"); });
    events.on!"baz"(() { writeln("baz triggered!"); });
    // events.on!"unknown"(() {}); // compile error!

    events.trigger!"foo";
    events.trigger(c!"baz");
    events.trigger("bar"); // dynamic dispatch
    // events.trigger!"unknown"; // compile error!
  }

}
