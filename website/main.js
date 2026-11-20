(function () {
  "use strict";

  var API_BASE = "https://zholdas-api-de89a64e4196.herokuapp.com";
  var LEGAL_BASE = API_BASE;
  var SUPPORTED = ["ru", "kk", "en"];
  var dict = window.ZHOLDAS_I18N || {};
  var current = "ru";

  // Russian copy comes straight from the markup, so the page reads correctly without JS.
  dict.ru = dict.ru || {};
  document.querySelectorAll("[data-i18n]").forEach(function (el) {
    var key = el.getAttribute("data-i18n");
    if (!(key in dict.ru)) dict.ru[key] = el.innerHTML;
  });
  document.querySelectorAll("[data-i18n-placeholder]").forEach(function (el) {
    var key = el.getAttribute("data-i18n-placeholder");
    if (!(key in dict.ru)) dict.ru[key] = el.getAttribute("placeholder");
  });

  function t(key) {
    var table = dict[current] || {};
    return key in table ? table[key] : dict.ru[key] || "";
  }

  function storageGet(key) {
    try { return window.localStorage.getItem(key); } catch (e) { return null; }
  }
  function storageSet(key, value) {
    try { window.localStorage.setItem(key, value); } catch (e) { /* private mode */ }
  }

  function detectLang() {
    var fromUrl = new URLSearchParams(window.location.search).get("lang");
    if (fromUrl === "kz") fromUrl = "kk";
    if (SUPPORTED.indexOf(fromUrl) !== -1) return fromUrl;
    var saved = storageGet("zholdas_lang");
    if (SUPPORTED.indexOf(saved) !== -1) return saved;
    var nav = (navigator.language || "ru").toLowerCase();
    if (nav.indexOf("kk") === 0 || nav.indexOf("kz") === 0) return "kk";
    if (nav.indexOf("en") === 0) return "en";
    return "ru";
  }

  function applyLang(lang) {
    current = lang;
    document.documentElement.lang = lang === "kk" ? "kk" : lang;
    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      var value = t(el.getAttribute("data-i18n"));
      if (value) el.innerHTML = value;
    });
    document.querySelectorAll("[data-i18n-placeholder]").forEach(function (el) {
      el.setAttribute("placeholder", t(el.getAttribute("data-i18n-placeholder")));
    });
    document.title = t("doc_title");
    document.querySelectorAll("[data-lang]").forEach(function (btn) {
      btn.setAttribute("aria-pressed", btn.getAttribute("data-lang") === lang ? "true" : "false");
    });
    document.querySelectorAll("[data-legal]").forEach(function (a) {
      a.href = LEGAL_BASE + "/" + a.getAttribute("data-legal") + "?lang=" + lang;
    });
    // Keep a finished form's success message in the new language.
    document.querySelectorAll("form[data-waitlist]").forEach(function (form) {
      var note = form.querySelector(".waitlist__note");
      if (form.dataset.state) note.textContent = t(form.dataset.state);
    });
  }

  document.querySelectorAll("[data-lang]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var lang = btn.getAttribute("data-lang");
      storageSet("zholdas_lang", lang);
      applyLang(lang);
    });
  });

  // Waitlist forms
  var EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  function setNote(form, key, kind) {
    var note = form.querySelector(".waitlist__note");
    form.dataset.state = key;
    note.textContent = t(key);
    note.classList.toggle("is-ok", kind === "ok");
    note.classList.toggle("is-err", kind === "err");
  }

  function detectPlatform() {
    var ua = navigator.userAgent || "";
    if (/iPhone|iPad|iPod/i.test(ua)) return "ios";
    if (/Android/i.test(ua)) return "android";
    return "any";
  }

  document.querySelectorAll("form[data-waitlist]").forEach(function (form) {
    form.addEventListener("submit", function (event) {
      event.preventDefault();
      var input = form.querySelector('input[type="email"]');
      var button = form.querySelector('button[type="submit"]');
      var email = (input.value || "").trim();
      if (!EMAIL_RE.test(email)) {
        setNote(form, "msg_invalid", "err");
        input.focus();
        return;
      }
      button.disabled = true;
      setNote(form, "msg_sending");

      fetch(API_BASE + "/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: email,
          lang: current,
          platform: detectPlatform(),
          source: form.getAttribute("data-source") || "landing",
          website: form.querySelector('input[name="website"]').value
        })
      })
        .then(function (res) {
          if (res.ok) {
            form.classList.add("is-done");
            setNote(form, "msg_ok", "ok");
          } else if (res.status === 400) {
            setNote(form, "msg_invalid", "err");
          } else if (res.status === 429) {
            setNote(form, "msg_rate", "err");
          } else {
            setNote(form, "msg_error", "err");
          }
        })
        .catch(function () { setNote(form, "msg_error", "err"); })
        .then(function () { button.disabled = false; });
    });
  });

  // Gentle reveal of sections while scrolling
  if ("IntersectionObserver" in window) {
    var targets = document.querySelectorAll(".step, .feature, .ev, .compare__col, .safety__list li, .org, .faq details, .cta");
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-in");
          io.unobserve(entry.target);
        }
      });
    }, { rootMargin: "0px 0px -8% 0px" });
    targets.forEach(function (el) { el.classList.add("reveal"); io.observe(el); });
  }

  applyLang(detectLang());
})();
