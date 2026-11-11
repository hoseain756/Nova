import fs from "node:fs";
import { fileURLToPath } from "node:url";
const read = (path) =>
  fs.readFileSync(new URL("../../" + path, import.meta.url), "utf8");
const src = read("lib/features/settings/settings_preferences_page.dart").split(
  "class SettingsPreferencesPage",
)[0];
const defaults = read("lib/core/state/app_state.dart");
const languages = ["ar", "en"].map((code) =>
  JSON.parse(read("lib/l10n/app_" + code + ".arb")),
);
const label = (key) => languages.map((dict) => dict[key] ?? key);
const entries = [];
for (const match of src.matchAll(
  /_Preference\(\s*key:\s*'([^']+)'([\s\S]*?)(?=\n\s*_Preference\(|\n\];)/g,
)) {
  const [, key, body] = match;
  const title = body.match(
    /arabic:\s*NovaStrings\.lookup\(false,\s*'([^']+)'/,
  )?.[1];
  if (!title) throw Error("Missing title: " + key);
  const options = [
    ...body.matchAll(
      /_Option\(\s*'([^']+)',\s*NovaStrings\.lookup\(false,\s*'([^']+)'/g,
    ),
  ].map(([, value, title]) => ({ value, label: label(title) }));
  const control = body.match(/control:\s*_Control\.(\w+)/)[1];
  const num = (name, fallback) =>
    Number(body.match(new RegExp(name + ":\\s*([-.\\d]+)"))?.[1] ?? fallback);
  const val = defaults.match(
    new RegExp(
      "'" + key + "'\\s*:\\s*('([^']+)'|false|true|-?[\\d.]+|\\[[^\\]]+\\])",
    ),
  );
  const value = val?.[2] ?? val?.[1] ?? options[0]?.value ?? "0";
  entries.push({
    key,
    title: label(title),
    group:
      match.index < src.indexOf("final _subtitlePreferences")
        ? "playback"
        : "subtitles",
    control,
    value:
      value === "true"
        ? "1"
        : value === "false"
          ? "0"
          : value.replace(/[[\]' ]/g, ""),
    options,
    min: num("min", 0),
    max: num("max", 100),
    step: num("step", 1),
  });
}
fs.writeFileSync(
  fileURLToPath(new URL("../src/preferences.json", import.meta.url)),
  JSON.stringify(entries, null, 2) + "\n",
);
console.log(entries.length + " preference controls");
