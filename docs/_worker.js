// Cloudflare Pages geo-router.
// Drop this file as _worker.js in any Pages project's output directory.
// Convention: default page is index.html, translations are index-{lang}.html.
//
// Test with ?_country=US or ?_country=EG to simulate geo from anywhere.

const ME_NORTH_AFRICA = [
  "EG","SA","AE","IQ","JO","LB","SY","KW",
  "QA","OM","BH","YE","PS","SD","LY","DZ","TN","MA",
];

// -- CONFIG: edit this per project --
const LANG_ROUTES = {
  ar: { countries: ME_NORTH_AFRICA, file: "/index-ar" },
  // Add more: fr: { countries: ["FR","BE","SN"], file: "/index-fr" },
};
// ------------------------------------

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/") {
      // Explicit ?lang= forces a specific language, skipping geo
      const lang = url.searchParams.get("lang");
      if (lang) {
        if (LANG_ROUTES[lang]) {
          return env.ASSETS.fetch(new Request(url.origin + LANG_ROUTES[lang].file, request));
        }
        // Default language (e.g. "en") → strip params, serve root index.html
        return env.ASSETS.fetch(new Request(url.origin + "/", request));
      }

      // Determine country: test override or real Cloudflare geo
      const country = url.searchParams.get("_country") || request.cf?.country || "";

      for (const [, route] of Object.entries(LANG_ROUTES)) {
        if (route.countries.includes(country)) {
          return env.ASSETS.fetch(new Request(url.origin + route.file, request));
        }
      }
    }

    // Default: serve static files as-is
    return env.ASSETS.fetch(request);
  },
};
