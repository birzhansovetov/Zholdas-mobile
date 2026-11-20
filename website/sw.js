// The old web app at zholdas.app registered a service worker here.
// This version removes itself so returning visitors get the landing page.
self.addEventListener("install", function () { self.skipWaiting(); });
self.addEventListener("activate", function (event) {
  event.waitUntil(
    self.registration.unregister().then(function () {
      return self.clients.matchAll({ type: "window" });
    }).then(function (clients) {
      clients.forEach(function (client) { client.navigate(client.url); });
    })
  );
});
