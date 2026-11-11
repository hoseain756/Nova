import { ExternalLink, RotateCcw, RotateCw } from "lucide-react";
import { useState } from "react";
import { createRoot } from "react-dom/client";
import { providers, settingNames } from "./data";
import "./review.css";
import "./style.css";
const pages: Record<string, string> = {
  Home: "home",
  Discover: "discover",
  Anime: "anime",
  Kids: "kids",
  Library: "library",
  "Sample series": "title/tide",
  "Episode sources": "sources/tide/3",
  Player: "player/tide/3",
  Calendar: "calendar",
  "Live TV": "live",
  Downloads: "downloads",
  "Magnet file picker": "magnet-files",
  "Shared collection": "collection/weekend",
  "New collection": "new-list",
  "Join invitation": "join",
  "Account menu": "account",
  "Profile picker": "profiles",
  "Profile management": "profiles/manage",
  "Profile editor": "profiles/edit/mira",
  "Create profile": "profiles/new",
  Onboarding: "onboarding",
  Welcome: "welcome",
  "Sign in": "auth/signin",
  "Sign up": "auth/signup",
  Verify: "auth/verify",
  Username: "auth/username",
  "Reset password": "auth/reset",
  "New password": "auth/password",
  "Upgrade guest": "auth/upgrade",
  Settings: "settings",
  "App icon": "settings/icon",
  "Navigation style": "settings/dock",
  ...Object.fromEntries(
    Object.entries(settingNames).map(([id, p]) => [
      "Settings · " + p[1],
      "settings/" + id,
    ]),
  ),
  ...Object.fromEntries(
    providers.map((p) => ["Service · " + p, "service/" + p]),
  ),
};
function Review() {
  const [device, setDevice] = useState("phone"),
    [rotated, rotate] = useState(false),
    [theme, setTheme] = useState("dark"),
    [lang, setLang] = useState("ar"),
    [scenario, setScenario] = useState("ready"),
    [platform, setPlatform] = useState("android"),
    [route, setRoute] = useState("home"),
    [large, setLarge] = useState(false),
    [motion, setMotion] = useState(false),
    [solid, setSolid] = useState(false),
    [run, setRun] = useState(0);
  const dims = device === "tablet" ? [1024, 768] : [390, 844];
  if (rotated) dims.reverse();
  const url =
    "./?" +
    new URLSearchParams({
      lang,
      theme,
      platform,
      scenario,
      size: large ? "200" : "100",
      device: platform === "ios" && device === "phone" ? "iphone" : device,
      motion: motion ? "off" : "on",
      glass: solid ? "off" : "on",
    }) +
    "#" +
    (scenario === "onboarding" && route === "home" ? "onboarding" : route);
  const select = (
    name: string,
    value: string,
    change: (s: string) => void,
    options: Record<string, string>,
  ) => (
    <label>
      {name}
      <select
        aria-label={name}
        value={value}
        onChange={(e) => change(e.target.value)}
      >
        {Object.entries(options).map(([label, val]) => (
          <option key={val} value={val}>
            {label}
          </option>
        ))}
      </select>
    </label>
  );
  return (
    <div className="review">
      <aside>
        <img src="/brand/wordmark_white.svg" alt="NOVA" />
        <h1>Design review</h1>
        {select("Screen", route, setRoute, pages)}
        {select("Viewport", device, setDevice, {
          Phone: "phone",
          Tablet: "tablet",
        })}
        {select("Platform", platform, setPlatform, {
          Android: "android",
          "iOS (simulated)": "ios",
        })}
        {select("Language", lang, setLang, { العربية: "ar", English: "en" })}
        {select("Appearance", theme, setTheme, {
          Dark: "dark",
          Light: "light",
          OLED: "oled",
        })}
        {select("Scenario", scenario, setScenario, {
          Populated: "ready",
          Empty: "empty",
          Loading: "loading",
          "Provider failure": "error",
          Offline: "offline",
          "Collection member": "member",
          "Version conflict": "conflict",
          "Missing download": "missing",
          "First run": "onboarding",
        })}
        <label className="check">
          <input
            type="checkbox"
            checked={large}
            onChange={(e) => setLarge(e.target.checked)}
          />
          200% text
        </label>
        <label className="check">
          <input
            type="checkbox"
            checked={motion}
            onChange={(e) => setMotion(e.target.checked)}
          />
          Reduce motion
        </label>
        <label className="check">
          <input
            type="checkbox"
            checked={solid}
            onChange={(e) => setSolid(e.target.checked)}
          />
          Reduce transparency
        </label>
        <div className="actions">
          <button aria-label="Rotate frame" onClick={() => rotate(!rotated)}>
            <RotateCw />
          </button>
          <button
            aria-label="Reset sample session"
            onClick={() => setRun(run + 1)}
          >
            <RotateCcw />
          </button>
          <a
            aria-label="Open full size"
            target="_blank"
            rel="noreferrer"
            href={url}
          >
            <ExternalLink />
          </a>
        </div>
        <small>
          Parent PIN 1234 · Mira PIN 2468. Review controls restart the sample
          session. Rotate preserves it.
        </small>
      </aside>
      <section className="review-stage">
        <p>
          {dims[0]} × {dims[1]}
        </p>
        <iframe
          key={run + "_" + url}
          title="NOVA interactive preview"
          src={url}
          style={{ width: dims[0], height: dims[1] }}
        />
      </section>
    </div>
  );
}
createRoot(document.getElementById("root")!).render(<Review />);
