import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, mkdirSync } from "node:fs";
import { spawn } from "node:child_process";
import { chromium } from "playwright";
import { fileURLToPath } from "node:url";

const cwd = fileURLToPath(new URL("../", import.meta.url));
let browser, server, base;
before(async () => {
  mkdirSync(new URL("../test-results/", import.meta.url), { recursive: true });
  server = spawn(
    process.execPath,
    ["node_modules/vite/bin/vite.js", "--host", "127.0.0.1", "--port", "0"],
    { cwd, stdio: ["ignore", "pipe", "pipe"] },
  );
  base = await new Promise((resolve, reject) => {
    const timeout = setTimeout(
      () => reject(Error("Preview server did not start")),
      30000,
    );
    server.stdout.on("data", (chunk) => {
      const url = String(chunk).match(/http:\/\/127\.0\.0\.1:\d+\//);
      if (url) {
        clearTimeout(timeout);
        resolve(url[0]);
      }
    });
    server.once("exit", (code) => {
      clearTimeout(timeout);
      reject(Error("Preview exited " + code));
    });
  });
  const executable =
    process.env.NOVA_BROWSER ||
    [
      "C:/Program Files/Google/Chrome/Application/chrome.exe",
      "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    ].find(existsSync);
  browser = await chromium.launch({
    headless: true,
    executablePath: executable,
  });
});
after(async () => {
  await browser?.close();
  server?.kill();
});
async function page(
  route = "home",
  params = "lang=en",
  size = { width: 390, height: 844 },
) {
  const p = await browser.newPage({ viewport: size });
  p.setDefaultTimeout(6500);
  await p.goto(base + "?" + params + "#" + route);
  await p.evaluate(() => document.fonts.ready);
  return p;
}
const click = (p, name) => p.getByRole("button", { name, exact: true }).click();
const waitRoute = (p, route) => p.waitForURL((url) => url.hash === "#" + route);
test("Home, source selection, checkpoint and library state", async () => {
  const p = await page();
  assert.ok(
    await p.getByRole("heading", { name: "Continue watching" }).isVisible(),
  );
  const start = await p
    .getByRole("heading", { name: "Continue watching" })
    .boundingBox();
  assert.ok(start.y < 844);
  await p.getByRole("button", { name: "Explore title" }).click();
  await waitRoute(p, "title/sand");
  await click(p, "Watch");
  await waitRoute(p, "sources/sand/1");
  await click(p, "Play 1080p");
  await waitRoute(p, "player/sand/1");
  await p.getByRole("slider", { name: "Playback position" }).focus();
  await p.keyboard.press("Home");
  await p.keyboard.press("ArrowRight");
  await click(p, "Exit");
  await click(p, "Save and exit");
  await waitRoute(p, "sources/sand/1");
  await click(p, "Back");
  await waitRoute(p, "title/sand");
  await click(p, "Back");
  await waitRoute(p, "home");
  await p.close();
});
test("Featured thumbnails select a title, retain it on return and share its saved state", async () => {
  const p = await page("home", "lang=ar");
  const picker = p.getByRole("group", { name: "اختيار العمل البارز" });
  const thumbnail = picker.getByRole("button", { name: "بعد منتصف الليل" });
  await thumbnail.focus();
  await p.keyboard.press("Enter");
  assert.equal(await thumbnail.getAttribute("aria-pressed"), "true");
  const feature = p.getByRole("region", { name: "العمل البارز" });
  await feature.getByRole("heading", { name: "بعد منتصف الليل" }).waitFor();
  await feature.getByRole("button", { name: "حفظ", exact: true }).click();
  await feature.getByRole("button", { name: "تفاصيل العمل" }).click();
  await waitRoute(p, "title/night");
  const detail = p.getByRole("region", { name: "بعد منتصف الليل" });
  await detail.getByRole("button", { name: "محفوظ" }).waitFor();
  await p.screenshot({ path: "test-results/hero-detail-ar.png" });
  await click(p, "رجوع");
  await waitRoute(p, "home");
  assert.equal(await thumbnail.getAttribute("aria-pressed"), "true");
  await click(p, "الأنمي");
  assert.equal(await picker.count(), 0);
  await p.goto(base + "?lang=en&theme=light#title/night");
  await p.setViewportSize({ width: 1024, height: 768 });
  await p.getByRole("heading", { name: "Past Midnight" }).waitFor();
  await p.evaluate(() => document.fonts.ready);
  const frame = await p.locator(".film-hero-frame").boundingBox();
  const title = await p.locator(".film-hero-title").boundingBox();
  assert.ok(title.x + title.width <= frame.x + 1);
  await p.screenshot({ path: "test-results/hero-detail-en-tablet.png" });
  await p.close();
});
test("Discovery restores search and does not show stale results", async () => {
  const p = await page();
  await click(p, "Search");
  await waitRoute(p, "discover/search");
  const input = p.getByRole("textbox", { name: "Search" });
  await input.fill("Last Light");
  await p.getByRole("button", { name: /Last Light/ }).click();
  await click(p, "Back");
  assert.equal(await input.inputValue(), "Last Light");
  await input.fill("no match");
  assert.ok(await p.getByRole("heading", { name: "No results" }).isVisible());
  await p.close();
});
test("Kids gates avatar, direct route, cancelled attempts and valid PIN", async () => {
  const p = await page();
  await p.locator("[data-tab=kids]").click();
  await waitRoute(p, "kids");
  await click(p, "Profile");
  await p.getByLabel("Parent PIN").fill("0000");
  await click(p, "Leave");
  assert.ok(await p.getByRole("alert").isVisible());
  await click(p, "Close");
  assert.equal(new URL(p.url()).hash, "#kids");
  await p.evaluate(() => (location.hash = "title/night"));
  await p.getByRole("dialog").waitFor();
  assert.equal(new URL(p.url()).hash, "#kids");
  await click(p, "Close");
  await p.locator("[data-tab=library]").click();
  await p.getByLabel("Parent PIN").fill("1234");
  await click(p, "Leave");
  await waitRoute(p, "library");
  await p.close();
});
test("Shared collection creation and profile scope", async () => {
  const p = await page("new-list");
  await p.getByLabel("Collection name").fill("Friday club");
  await p.getByRole("checkbox").check();
  await click(p, "Create");
  await click(p, "Add title");
  await p
    .getByRole("dialog")
    .getByRole("button", { name: "Little Fox" })
    .click();
  assert.ok(await p.getByRole("button", { name: /Little Fox/ }).isVisible());
  await p.evaluate(() => (location.hash = "profiles"));
  await p.getByRole("button", { name: /Mira/ }).click();
  await p.getByLabel("PIN", { exact: true }).fill("2468");
  await click(p, "Unlock");
  await waitRoute(p, "home");
  await p.locator("[data-tab=library]").click();
  assert.ok(
    await p.getByRole("heading", { name: "No titles here yet" }).isVisible(),
  );
  await click(p, "Collections");
  await p.getByRole("button", { name: /Friday club/ }).waitFor();
  await p.close();
});
test("Source failure, retry, offline download and platform controls", async () => {
  const p = await page(
    "sources/sand/1/download",
    "lang=en&platform=ios&scenario=error",
  );
  await click(p, "Retry");
  assert.equal(
    await p.getByRole("button", { name: "Download 2160p" }).isDisabled(),
    true,
  );
  await click(p, "Download 720p");
  await waitRoute(p, "downloads");
  await click(p, "Cancel");
  await click(p, "Retry");
  await p.getByText("Ready · 100%").nth(1).waitFor({ timeout: 11000 });
  await p.evaluate(() => (location.hash = "settings/playback"));
  await p.getByText("libmpv · iOS").waitFor();
  await p.close();
});
test("Sign-up, first profile, review controls, form preservation", async () => {
  const p = await page("auth/signup", "lang=en&scenario=offline");
  await p.getByLabel("Username").fill("Sample");
  await p.getByLabel("Email").fill("nova@example.test");
  await p.getByLabel("Password").fill("sample-only");
  await click(p, "Continue");
  assert.equal(await p.getByLabel("Username").inputValue(), "Sample");
  await click(p, "Continue");
  await waitRoute(p, "auth/verify");
  await click(p, "Continue");
  await p.getByLabel("Username").fill("tester");
  await click(p, "Continue");
  await waitRoute(p, "profiles/new");
  await p.getByLabel("Name", { exact: true }).fill("New viewer");
  await click(p, "Save");
  await waitRoute(p, "home");
  await p.goto(base + "review.html");
  await p.getByLabel("Viewport").selectOption("tablet");
  await p.getByLabel("Language", { exact: true }).selectOption("en");
  await p
    .frameLocator("iframe")
    .getByRole("heading", { name: "The Sand Atlas" })
    .waitFor();
  await p.close();
});
test("Screen inventory opens and remains within both reference viewports", async () => {
  for (const [lang, width, height] of [
    ["ar", 390, 844],
    ["en", 1024, 768],
  ]) {
    const p = await page("home", "lang=" + lang, { width, height });
    const errors = [];
    p.on("pageerror", (e) => errors.push(e.message));
    await p.screenshot({ path: "test-results/home-" + lang + ".png" });
    const routes = [
      "home",
      "discover",
      "anime",
      "kids",
      "library",
      "calendar",
      "live",
      "title/tide",
      "sources/tide/3",
      "player/tide/3",
      "onboarding",
      "account",
      "downloads",
      "magnet-files",
      "new-list",
      "join",
      "collection/weekend",
      "profiles/manage",
      "profiles/new",
      "welcome",
      "auth/signin",
      "auth/signup",
      "auth/verify",
      "auth/reset",
      "auth/password",
      "auth/username",
      "auth/upgrade",
      "settings",
      "settings/account",
      "settings/playback",
      "settings/subtitles",
      "settings/downloads",
      "settings/appearance",
      "settings/display",
      "settings/catalogs",
      "settings/language",
      "settings/notifications",
      "settings/privacy",
      "settings/addons",
      "settings/services",
      "settings/kids",
      "settings/stats",
      "settings/about",
      "settings/icon",
      "settings/dock",
      "service/Letterboxd",
      "service/Trakt",
      "service/Simkl",
      "service/AniList",
      "service/MyAnimeList",
      "service/MDBList",
      "service/TMDB",
      "service/Debrid",
      "service/AniSkip",
      "service/IntroDB",
      "service/TheIntroDB",
      "addon/Cinemeta",
    ];
    for (const path of routes) {
      await p.goto(base + "?lang=" + lang + "#" + path);
      await p.locator("main").waitFor();
      assert.equal(
        await p
          .getByRole("heading", {
            name: /Page unavailable|هذه الصفحة غير متاحة/,
          })
          .count(),
        0,
        path,
      );
      const overflow = await p.evaluate(
        () => document.documentElement.scrollWidth - innerWidth,
      );
      assert.ok(overflow <= 1, path + " overflows by " + overflow);
    }
    assert.deepEqual(errors, []);
    await p.close();
  }
});
test("Member restrictions, conflicts, spoilers and exact episode marks", async () => {
  const p = await page("collection/weekend", "lang=en&scenario=member");
  assert.equal(await p.getByRole("button", { name: "Rename" }).count(), 0);
  await click(p, "Members & invitations");
  assert.equal(
    await p.getByRole("button", { name: "Rotate invite" }).count(),
    0,
  );
  await click(p, "Close");
  await p.goto(base + "?lang=en&scenario=conflict#collection/weekend");
  await click(p, "Rename");
  await p.getByLabel("Name", { exact: true }).fill("Saturday cinema");
  await click(p, "Save");
  await click(p, "Reload and retry");
  assert.equal(
    await p.getByLabel("Name", { exact: true }).inputValue(),
    "Saturday cinema",
  );
  await click(p, "Save");
  await p.getByRole("heading", { name: "Saturday cinema" }).waitFor();
  await p.evaluate(() => (location.hash = "title/tide"));
  await click(p, "Episode options 4");
  await click(p, "Mark watched through this episode");
  assert.equal(await p.getByText("Watched", { exact: true }).count(), 5);
  assert.equal(await p.getByText(/The ending changes/).count(), 0);
  await p.getByRole("button", { name: /Review by Mira/ }).click();
  await p.getByRole("button", { name: /Review by Mira/ }).click();
  await p.getByRole("dialog").waitFor();
  await p.close();
});
test("Large text, landscape, theme and transparency", async () => {
  const p = await page(
    "home",
    "lang=ar&theme=oled&size=200&device=iphone&platform=ios&glass=off&motion=off",
    { width: 844, height: 390 },
  );
  assert.equal(await p.locator("html").getAttribute("dir"), "rtl");
  assert.equal(
    await p
      .locator(".dock")
      .evaluate((el) => getComputedStyle(el).flexDirection),
    "row",
  );
  for (const path of [
    "home",
    "title/tide",
    "settings/subtitles",
    "player/tide/3",
    "library",
    "discover",
  ]) {
    await p.goto(
      base +
        "?lang=ar&theme=oled&size=200&device=iphone&glass=off&motion=off#" +
        path,
    );
    await p.locator("main").waitFor();
    assert.ok(
      await p.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth + 1,
      ),
      path,
    );
  }
  await p.setViewportSize({ width: 360, height: 740 });
  await p.goto(base + "?lang=en&theme=light&size=200#settings/appearance");
  assert.ok(
    await p.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth + 1,
    ),
  );
  await p.close();
});
test("Playlist form, calendar, source preparation and back context", async () => {
  const p = await page("live");
  await click(p, "Add playlist");
  await p.getByLabel("Name", { exact: true }).fill("Cinema channel");
  await p.getByLabel("M3U URL").fill("https://example.test/film.m3u");
  await click(p, "Add");
  await p
    .getByRole("button", { name: /Cinema channel Demo broadcast/ })
    .click();
  await waitRoute(p, "player/fox/1/live");
  await p.goto(base + "?lang=en#calendar");
  await click(p, "Next week");
  await p.getByRole("heading", { name: /November/ }).waitFor();
  await p.goto(base + "?lang=en#sources/sand/1");
  await click(p, "Play 2160p");
  await p.getByRole("dialog", { name: "Preparing torrent" }).waitFor();
  await click(p, "Cancel");
  assert.equal(new URL(p.url()).hash, "#sources/sand/1");
  await p.close();
});
