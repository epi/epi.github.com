#define BOOST_HANA_CONFIG_ENABLE_STRING_UDL
#include <cassert>
#include <functional>
#include <iostream>
#include <string>
#include <unordered_map>
#include <vector>
#include <boost/hana/contains.hpp>
#include <boost/hana/map.hpp>
#include <boost/hana/string.hpp>
#include <boost/hana/for_each.hpp>
#include <boost/hana/at_key.hpp>

namespace hana = boost::hana;
using namespace hana::literals;
using namespace std::literals;

template <typename ...Events>
struct event_system {
  using Callback = std::function<void()>;
  hana::map<hana::pair<Events, std::vector<Callback>>...> map_;

  std::unordered_map<std::string, std::vector<Callback>* const> dynamic_;

  event_system() {
    hana::for_each(hana::keys(map_), [&](auto event) {
      dynamic_.insert({event.c_str(), &map_[event]});
    });
  }

  template <typename Event, typename F>
  void on(Event e, F callback) {
    auto is_known_event = hana::contains(map_, e);
    static_assert(is_known_event,
      "trying to add a callback to an unknown event");

    map_[e].push_back(callback);
  }

  template <typename Event>
  void trigger(Event e) const {
    auto is_known_event = hana::contains(map_, e);
    static_assert(is_known_event,
      "trying to trigger an unknown event");

    for (auto& callback : map_[e])
      callback();
  }

  void trigger(std::string const& event) {
    auto callbacks = dynamic_.find(event);
    assert(callbacks != dynamic_.end() &&
      "trying to trigger an unknown event");

    for (auto& callback : *callbacks->second)
      callback();
  }
};

template <typename ...Events>
event_system<Events...> make_event_system(Events ...events) {
  return {};
}

#ifndef BENCHMARK

int main() {
  auto events = make_event_system("foo"_s, "bar"_s, "baz"_s);

  events.on("foo"_s, []() { std::cout << "foo triggered!" << '\n'; });
  events.on("foo"_s, []() { std::cout << "foo again!" << '\n'; });
  events.on("bar"_s, []() { std::cout << "bar triggered!" << '\n'; });
  events.on("baz"_s, []() { std::cout << "baz triggered!" << '\n'; });
  // events.on("unknown"_s, []() {}); // compiler error!

  events.trigger("foo"_s); // no overhead
  events.trigger("bar"_s);
  events.trigger("baz"s);
  // events.trigger("unknown"_s); // compiler error!
}

#else

#include <chrono>

int main() {
  auto events = make_event_system("foo"_s, "bar"_s, "baz"_s);

  using ns = std::chrono::nanoseconds;
  using clock = std::chrono::steady_clock;

  auto foos = std::string("foo");
  auto bars = std::string("bar");
  auto bazs = std::string("baz");

  events.on("foo"_s, [](){});
  events.on("bar"_s, [](){});
  events.on("baz"_s, [](){});

  std::function<void()> foo_fun = [](){};
  std::function<void()> bar_fun = [](){};
  std::function<void()> baz_fun = [](){};

  auto n = 100000000;

  auto t0 = clock::now();
  for (int i = 0; i < n; i++) {
    events.trigger(foos);
    events.trigger(bars);
    events.trigger(foos);
    events.trigger(bars);
    events.trigger(bazs);
  }
  auto t1 = clock::now();
  for (int i = 0; i < n; i++) {
    events.trigger("foo"_s);
    events.trigger("bar"_s);
    events.trigger("foo"_s);
    events.trigger("bar"_s);
    events.trigger("baz"_s);
  }
  auto t2 = clock::now();
  for (int i = 0; i < n; i++) {
    foo_fun();
    bar_fun();
    foo_fun();
    bar_fun();
    baz_fun();
  }
  auto t3 = clock::now();

  std::cout
    << std::chrono::duration_cast<ns>(t1 - t0).count() / (n * 5.0) << " "
    << std::chrono::duration_cast<ns>(t2 - t1).count() / (n * 5.0) << " "
    << std::chrono::duration_cast<ns>(t3 - t2).count() / (n * 5.0) << "\n";
}

#endif
