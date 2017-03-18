#include <functional>
#include <unordered_map>
#include <vector>
#include <iostream>
#include <cassert>
#include <initializer_list>

struct event_system {
  using Callback = std::function<void()>;
  std::unordered_map<std::string, std::vector<Callback>> map_;

  explicit event_system(std::initializer_list<std::string> events) {
    for (auto const& event : events)
      map_.insert({event, {}});
  }

  template <typename F>
  void on(std::string const& event, F callback) {
    auto callbacks = map_.find(event);
    assert(callbacks != map_.end() &&
      "trying to add a callback to an unknown event");

    callbacks->second.push_back(callback);
  }

  void trigger(std::string const& event) {
    auto callbacks = map_.find(event);
    assert(callbacks != map_.end() &&
      "trying to trigger an unknown event");

    for (auto& callback : callbacks->second)
      callback();
  }
};

int main() {
  event_system events({"foo", "bar", "baz"});

  events.on("foo", []() { std::cout << "foo triggered!" << '\n'; });
  events.on("foo", []() { std::cout << "foo again!" << '\n'; });
  events.on("bar", []() { std::cout << "bar triggered!" << '\n'; });
  events.on("baz", []() { std::cout << "baz triggered!" << '\n'; });

  events.trigger("foo");
  events.trigger("baz");
  events.trigger("unknown"); // WOOPS! Runtime error!
}
