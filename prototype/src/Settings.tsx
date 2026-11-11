import { ArrowDown, ArrowUp, Link, Plus, Search, Unlink } from "lucide-react";
import { useState } from "react";
import {
  emptyLibrary,
  films,
  providers,
  settingNames,
  type Pair,
} from "./data";
import definitions from "./preferences.json";
import { useNova } from "./session";
import { Btn, Heading, Modal, Row } from "./ui";
type Section = keyof typeof settingNames;
const groups: [Pair, Section[]][] = [
  [
    ["الحساب والعائلة", "Account & family"],
    ["account", "kids", "privacy"],
  ],
  [
    ["المشاهدة", "Watching"],
    ["playback", "subtitles", "downloads", "stats"],
  ],
  [
    ["المحتوى والخدمات", "Content & services"],
    ["display", "catalogs", "addons", "services"],
  ],
  [
    ["التطبيق والتخصيص", "App & personalization"],
    ["appearance", "language", "notifications", "about"],
  ],
];
function Toggle({
  id,
  label,
  initial = false,
}: {
  id: string;
  label: string;
  initial?: boolean;
}) {
  const n = useNova();
  return (
    <label className="control-row">
      <span>{label}</span>
      <input
        type="checkbox"
        role="switch"
        checked={(n.prefs[id] ?? (initial ? "1" : "0")) === "1"}
        onChange={(e) => n.pref(id, e.target.checked ? "1" : "0")}
      />
    </label>
  );
}
function Select({
  id,
  label,
  items,
  initial,
}: {
  id: string;
  label: string;
  items: [string, string][];
  initial?: string;
}) {
  const n = useNova();
  return (
    <label className="control-row">
      <span>{label}</span>
      <select
        value={n.prefs[id] ?? initial ?? items[0][0]}
        onChange={(e) => n.pref(id, e.target.value)}
      >
        {items.map(([id, label]) => (
          <option key={id} value={id}>
            {label}
          </option>
        ))}
      </select>
    </label>
  );
}
function Preference({ d }: { d: (typeof definitions)[number] }) {
  const n = useNova(),
    label = d.title[n.en ? 1 : 0],
    val = n.prefs[d.key] ?? d.value;
  if (d.key === "playbackBackend" && n.platform === "ios")
    return <Row title={label} note="libmpv · iOS" />;
  if (d.control === "toggle")
    return <Toggle id={d.key} label={label} initial={d.value === "1"} />;
  if (d.control === "select")
    return (
      <Select
        id={d.key}
        label={label}
        initial={d.value}
        items={d.options.map((o) => [o.value, o.label[n.en ? 1 : 0]])}
      />
    );
  if (d.control === "multiple")
    return (
      <fieldset>
        <legend>{label}</legend>
        {d.options.map((o) => (
          <label className="check" key={o.value}>
            <input
              type="checkbox"
              checked={val.split(",").includes(o.value)}
              onChange={(e) =>
                n.pref(
                  d.key,
                  (e.target.checked
                    ? [...val.split(",").filter(Boolean), o.value]
                    : val.split(",").filter((x) => x !== o.value)
                  ).join(","),
                )
              }
            />
            {o.label[n.en ? 1 : 0]}
          </label>
        ))}
      </fieldset>
    );
  return (
    <label className="control-row">
      <span>
        {label}
        {d.control === "slider" && <small>{val}</small>}
      </span>
      <input
        type={d.control === "slider" ? "range" : "color"}
        min={d.min}
        max={d.max}
        step={d.step}
        value={val}
        onChange={(e) => n.pref(d.key, e.target.value)}
      />
    </label>
  );
}
export function Settings({ section }: { section?: string }) {
  const n = useNova(),
    [query, setQuery] = useState(""),
    [panel, setPanel] = useState(""),
    [input, setInput] = useState(""),
    [error, setError] = useState("");
  const heading = settingNames[section as Section];
  const tr = n.tr;
  function ask(action: string) {
    setPanel(action);
    setInput("");
    setError("");
  }
  function apply() {
    switch (panel) {
      case "pin":
        if (!/^\d{4}$/.test(input)) {
          setError(tr("أدخل أربعة أرقام", "Enter four digits"));
          return;
        }
        n.setParentPin(input);
        break;
      case "history":
        n.editLib((l) => ({ ...l, progress: {}, watched: {} }));
        break;
      case "library":
        n.editLib((l) => ({
          ...emptyLibrary(),
          shelves: l.shelves.filter((s) => s.shared),
        }));
        break;
      case "cache":
        n.pref("cache", "cleared");
        break;
      case "import":
        n.editLib((l) => ({
          ...l,
          saved: [...new Set([...l.saved, "orbit"])],
        }));
        break;
      case "restore":
        try {
          const data = JSON.parse(input);
          if (
            !Array.isArray(data.saved) ||
            data.saved.some((id: unknown) => !films.some((m) => m.id === id))
          )
            throw Error();
          n.editLib((l) => ({ ...l, saved: [...new Set<string>(data.saved)] }));
        } catch {
          setError(tr("نسخة غير صالحة", "Invalid sample backup"));
          return;
        }
        break;
      case "addon":
        if (!input.trim()) {
          setError(tr("أدخل اسم الإضافة", "Enter an add-on name"));
          return;
        }
        n.setInstalled((a) => [...new Set([...a, input.trim()])]);
        n.setCatalogs((a) => [...new Set([...a, input.trim()])]);
        break;
    }
    n.setToast(tr("تم الحفظ", "Saved"));
    setPanel("");
  }
  if (!section)
    return (
      <div className="page">
        <Heading back title={tr("الإعدادات", "Settings")} />
        <label className="search">
          <Search />
          <input
            value={query}
            placeholder={tr("ابحث في الإعدادات", "Find a setting")}
            onChange={(e) => setQuery(e.target.value)}
          />
        </label>
        {groups.map(([label, ids]) => {
          const hits = ids.filter((id) =>
            [
              ...settingNames[id],
              id,
              ...(id === "playback" ? ["Media3", "ExoPlayer", "libmpv"] : []),
            ].some((x) => x.toLowerCase().includes(query.toLowerCase())),
          );
          return (
            hits.length > 0 && (
              <section key={label[1]}>
                <h2>{n.t(label)}</h2>
                {hits.map((id) => (
                  <Row
                    key={id}
                    title={n.t(settingNames[id])}
                    onClick={() => n.go("settings/" + id)}
                  />
                ))}
              </section>
            )
          );
        })}
      </div>
    );
  const titles: Record<string, string> = {
    pin: tr("تغيير رمز الأهل", "Change parent PIN"),
    history: tr("مسح السجل", "Clear history"),
    library: tr("مسح بيانات المكتبة", "Clear library data"),
    cache: tr("مسح ذاكرة التخزين", "Clear cache"),
    import: tr("استيراد بيانات قديمة", "Import legacy data"),
    restore: tr("استعادة نسخة", "Restore backup"),
    addon: tr("تثبيت إضافة تجريبية", "Install sample add-on"),
  };
  const choose = (id: string, label: string, options: Pair[]) => (
    <Select id={id} label={label} items={options.map((o) => [o[1], n.t(o)])} />
  );
  return (
    <div className="settings-layout">
      <aside
        className="settings-rail"
        aria-label={tr("أقسام الإعدادات", "Settings sections")}
      >
        <h2>{tr("الإعدادات", "Settings")}</h2>
        {groups.map(([group, ids]) => (
          <section key={group[1]}>
            <h3>{n.t(group)}</h3>
            {ids.map((id) => (
              <button
                key={id}
                aria-current={id === section ? "page" : undefined}
                onClick={() => n.go("settings/" + id, true)}
              >
                {n.t(settingNames[id])}
              </button>
            ))}
          </section>
        ))}
      </aside>
      <div className="page narrow">
        <Heading
          back
          title={
            heading
              ? n.t(heading)
              : section === "icon"
                ? tr("أيقونة التطبيق", "App icon")
                : tr("شريط التنقل", "Navigation style")
          }
        />
        {["playback", "subtitles"].includes(section) && (
          <>
            {definitions
              .filter((d) => d.group === section)
              .map((d) => (
                <Preference d={d} key={d.key} />
              ))}
            {section === "playback" ? (
              choose("mpvQuality", tr("معالجة الصورة", "Picture processing"), [
                ["متوازن", "Balanced"],
                ["أداء", "Performance"],
                ["جودة", "Quality"],
              ])
            ) : (
              <>
                <Select
                  id="subFontFamily"
                  label={tr("خط الترجمة", "Subtitle font")}
                  items={[
                    "Netflix Sans",
                    "Poppins",
                    "IBM Plex Sans Arabic",
                    ...(n.prefs.importedFont ? [n.prefs.importedFont] : []),
                  ].map((x) => [x, x])}
                />
                <label>
                  {tr("إضافة خط محلي", "Import local font")}
                  <input
                    type="file"
                    accept=".ttf,.otf"
                    onChange={(e) => {
                      const f = e.target.files?.[0];
                      if (f) n.pref("importedFont", f.name);
                    }}
                  />
                </label>
              </>
            )}
          </>
        )}
        {section === "appearance" && (
          <>
            <label className="control-row">
              {tr("السمة", "Theme")}
              <select
                value={n.theme}
                onChange={(e) => n.setTheme(e.target.value)}
              >
                {["dark", "light", "system", "oled"].map((x, i) => (
                  <option key={x} value={x}>
                    {
                      [
                        tr("داكن", "Dark"),
                        tr("فاتح", "Light"),
                        tr("النظام", "System"),
                        "OLED",
                      ][i]
                    }
                  </option>
                ))}
              </select>
            </label>
            <Toggle
              id="reduceMotion"
              label={tr("تقليل الحركة", "Reduce motion")}
            />
            <Toggle
              id="reduceTransparency"
              label={tr("تقليل الشفافية", "Reduce transparency")}
            />
            <Row
              title={tr("أيقونة التطبيق", "App icon")}
              onClick={() => n.go("settings/icon")}
            />
            <Row
              title={tr("نمط شريط التنقل", "Navigation style")}
              onClick={() => n.go("settings/dock")}
            />
          </>
        )}
        {section === "icon" && (
          <>
            <img className="brand-mark" src="/brand/icon_red.svg" alt="NOVA" />
            {choose("appIcon", tr("أيقونة التطبيق", "App icon"), [
              ["كلاسيكي", "Classic"],
              ["شفاف", "Clear"],
              ["داكن", "Dark"],
            ])}
          </>
        )}
        {section === "dock" &&
          choose("dock", tr("النمط", "Style"), [
            ["كلاسيكي", "Classic"],
            ["مضغوط", "Compact"],
            ["مصغّر", "Mini"],
          ])}
        {section === "language" && (
          <>
            <label className="control-row">
              {tr("لغة الواجهة", "Interface language")}
              <select
                value={n.en ? "en" : "ar"}
                onChange={(e) => n.setEn(e.target.value === "en")}
              >
                <option value="ar">العربية</option>
                <option value="en">English</option>
              </select>
            </label>
            <Select
              id="contentLanguage"
              label={tr("لغة المحتوى", "Content language")}
              items={[
                "English",
                "العربية",
                "Español",
                "Français",
                "Deutsch",
                "Italiano",
                "Português",
                "日本語",
                "한국어",
                "中文",
                "Русский",
              ].map((x) => [x, x])}
            />
          </>
        )}
        {section === "display" && (
          <>
            {choose("homeMode", tr("عرض الرئيسية", "Home layout"), [
              ["سينمائي", "Cinematic"],
              ["كلاسيكي", "Classic"],
            ])}
            {[
              [
                "hideWatchedInCatalogs",
                "إخفاء الأعمال المشاهدة",
                "Hide watched titles",
              ],
              ["hideAnime", "إخفاء الأنمي في الرئيسية", "Hide anime on Home"],
              ["hideAdult", "إخفاء محتوى الكبار", "Hide adult content"],
              ["showImdbBadge", "عرض التقييم", "Show ratings"],
              [
                "hidePosterTitles",
                "إخفاء عناوين الملصقات",
                "Hide poster titles",
              ],
              [
                "blurEpisodeThumbnails",
                "تمويه صور الحلقات",
                "Blur episode stills",
              ],
              ["dockAutoHide", "إخفاء الشريط تلقائيًا", "Auto-hide navigation"],
            ].map(([id, ar, en]) => (
              <Toggle
                key={id}
                id={id}
                label={tr(ar, en)}
                initial={id === "showImdbBadge" || id === "dockAutoHide"}
              />
            ))}
            <label className="control-row">
              {tr("استدارة الملصقات", "Poster radius")}
              <input
                type="range"
                min="0"
                max="28"
                value={n.prefs.posterRadius ?? 16}
                onChange={(e) => n.pref("posterRadius", e.target.value)}
              />
            </label>
            {choose("episodesView", tr("عرض الحلقات", "Episode layout"), [
              ["تلقائي", "Auto"],
              ["قائمة", "List"],
              ["شبكة", "Grid"],
            ])}
            {choose("librarySort", tr("ترتيب المكتبة", "Library order"), [
              ["الأحدث", "Recent"],
              ["العنوان", "Title"],
              ["السنة", "Year"],
            ])}
          </>
        )}
        {section === "kids" && (
          <>
            {choose("kidsCardSize", tr("حجم البطاقات", "Card size"), [
              ["متوسط", "Medium"],
              ["كبير", "Large"],
              ["صغير", "Small"],
            ])}
            <Row title={titles.pin} onClick={() => ask("pin")} />
          </>
        )}
        {section === "catalogs" &&
          n.catalogs.map((x, i) => (
            <div key={x} className="control-row">
              <label className="check">
                <input
                  type="checkbox"
                  checked={n.prefs["hide." + x] !== "1"}
                  onChange={(e) =>
                    n.pref("hide." + x, e.target.checked ? "0" : "1")
                  }
                />
                {x}
              </label>
              <div className="actions">
                {[-1, 1].map((delta) => (
                  <button
                    key={delta}
                    aria-label={(delta === 1 ? "Down " : "Up ") + x}
                    disabled={i + delta < 0 || i + delta >= n.catalogs.length}
                    onClick={() =>
                      n.setCatalogs((old) => {
                        const a = [...old];
                        [a[i], a[i + delta]] = [a[i + delta], a[i]];
                        return a;
                      })
                    }
                  >
                    {delta === 1 ? <ArrowDown /> : <ArrowUp />}
                  </button>
                ))}
              </div>
            </div>
          ))}
        {section === "services" && (
          <>
            {providers.map((p) => (
              <Row
                key={p}
                title={p}
                note={
                  n.linked.includes(p) ? tr("متصل", "Connected") : undefined
                }
                onClick={() => n.go("service/" + p)}
              />
            ))}
            {["cw", "library"].map((key, i) => (
              <Select
                key={key}
                id={"provider." + key}
                label={
                  i
                    ? tr("مصدر المكتبة", "Library source")
                    : tr("مصدر متابعة المشاهدة", "Continue Watching source")
                }
                items={["Auto", ...providers.slice(0, 5)].map((x) => [x, x])}
              />
            ))}
          </>
        )}
        {section === "addons" && (
          <>
            {n.installed.map((x) => (
              <Row
                key={x}
                title={x}
                onClick={() => n.go("addon/" + encodeURIComponent(x))}
              />
            ))}
            <Btn onClick={() => ask("addon")}>
              <Plus />
              {titles.addon}
            </Btn>
          </>
        )}
        {section === "account" && (
          <>
            <Row
              title={n.profile.name}
              note={
                n.guest ? tr("ضيف", "Guest") : tr("حساب تجريبي", "Demo account")
              }
              onClick={() => n.go("profiles/manage")}
            />
            <Row
              title={tr("تبديل الملف", "Switch profile")}
              onClick={() => n.go("profiles")}
            />
            {n.guest && (
              <Row
                title={tr("ترقية حساب الضيف", "Upgrade guest account")}
                onClick={() => n.go("auth/upgrade")}
              />
            )}
            <Row title={titles.import} onClick={() => ask("import")} />
            <Row
              title={tr("تسجيل الخروج", "Sign out")}
              onClick={() => n.go("welcome")}
            />
          </>
        )}
        {section === "downloads" && (
          <>
            <Row
              title={tr("التنزيلات", "Downloads")}
              note={String(n.downloads.length)}
              onClick={() => n.go("downloads")}
            />
            <Row title={titles.cache} onClick={() => ask("cache")} />
          </>
        )}
        {section === "privacy" && (
          <>
            {["history", "library", "restore"].map((id) => (
              <Row key={id} title={titles[id]} onClick={() => ask(id)} />
            ))}
            <Row
              title={tr("تصدير نسخة تجريبية", "Export sample backup")}
              onClick={() => ask("backup")}
            />
          </>
        )}
        {section === "stats" && (
          <>
            {[
              [tr("قائمة المشاهدة", "Watchlist"), n.lib.saved.length],
              [
                tr("سجل المشاهدة", "Viewing history"),
                Object.keys(n.lib.progress).length,
              ],
              [tr("مجموعات", "Collections"), n.lib.shelves.length],
            ].map(([s, v]) => (
              <Row title={String(s)} key={s}>
                <strong>{v}</strong>
              </Row>
            ))}
            <h2>{tr("النشاط الأخير", "Recent activity")}</h2>
            {Object.entries(n.lib.progress).map(([id, p]) => {
              const m = films.find((x) => x.id === id);
              return (
                m && (
                  <Row
                    key={id}
                    title={n.t(m.name)}
                    note={p.pct + "%"}
                    onClick={() => n.go("title/" + id)}
                  />
                )
              );
            })}
            <Row title={titles.history} onClick={() => ask("history")} />
          </>
        )}
        {section === "notifications" && (
          <Row
            title={tr("إشعارات النظام", "System notifications")}
            note={tr(
              "تُدار أذونات الإشعارات من إعدادات الجهاز.",
              "Manage notification permissions in device settings.",
            )}
          />
        )}
        {section === "about" && (
          <>
            <img className="brand-mark" src="/brand/icon_red.svg" alt="NOVA" />
            <Row
              title="NOVA"
              note={tr("نسخة المعاينة المحلية", "Local preview build")}
            />
            {n.platform !== "ios" && (
              <Row
                title={tr("التحقق من التحديثات", "Check for updates")}
                onClick={() =>
                  n.setToast(
                    tr(
                      "هذه هي النسخة التجريبية الحالية",
                      "This sample build is current",
                    ),
                  )
                }
              />
            )}
          </>
        )}
        {panel && (
          <Modal
            title={titles[panel] || tr("نسخة تجريبية", "Sample backup")}
            onClose={() => setPanel("")}
          >
            {panel === "backup" ? (
              <textarea
                readOnly
                aria-label={tr("نسخة", "Backup")}
                value={JSON.stringify({ saved: n.lib.saved })}
              />
            ) : (
              <>
                {["restore", "addon", "pin"].includes(panel) ? (
                  <label>
                    {titles[panel]}
                    <input
                      value={input}
                      onChange={(e) => setInput(e.target.value)}
                    />
                  </label>
                ) : (
                  <p>
                    {tr(
                      "تطبيق هذا الإجراء على البيانات التجريبية؟",
                      "Apply this action to the sample data?",
                    )}
                  </p>
                )}
                {error && <p role="alert">{error}</p>}
                <Btn primary onClick={apply}>
                  {tr("تأكيد", "Confirm")}
                </Btn>
              </>
            )}
          </Modal>
        )}
      </div>
    </div>
  );
}
const features: Record<string, Pair[]> = {
  TMDB: [
    ["المقاطع", "Trailers"],
    ["الصور", "Artwork"],
    ["المعلومات الأساسية", "Basic info"],
    ["التفاصيل", "Details"],
    ["طاقم العمل", "Credits"],
    ["الإنتاج", "Production"],
    ["الشبكات", "Networks"],
    ["الحلقات", "Episodes"],
    ["ملصقات المواسم", "Season posters"],
    ["التوصيات", "Recommendations"],
    ["المجموعات", "Collections"],
  ],
  MDBList: [
    "IMDb",
    "TMDB",
    "Rotten Tomatoes",
    "Metacritic",
    "Trakt",
    "Letterboxd",
    "RT Audience",
    "MyAnimeList",
  ].map((x) => [x, x]),
  Simkl: [
    ["صفوف الرئيسية", "Home rows"],
    ["أفلام مخطط لها", "Planned movies"],
    ["مسلسلات قيد المتابعة", "Watching series"],
    ["مسلسلات مخطط لها", "Planned series"],
    ["أنمي قيد المتابعة", "Watching anime"],
    ["أنمي مخطط له", "Planned anime"],
    ["الحلقة التالية", "Up next"],
    ["رائج اليوم", "Trending today"],
    ["التقييم الشخصي", "Personal rating"],
  ],
  Letterboxd: [
    ["الأكثر رواجًا", "Popular"],
    ["أفضل ٢٥٠", "Top 250"],
    ["قائمة المشاهدة", "Watchlist"],
    ["المفضلة", "Favorites"],
    ["اليوميات", "Diary"],
    ["الأصدقاء", "Friends"],
    ["المقترحات", "Recommendations"],
    ["تقييمات الملصقات", "Poster ratings"],
    ["تمويه المراجعات", "Blur reviews"],
  ],
  Trakt: [
    ["تعليقات الجمهور", "Comments"],
    ["إخفاء الحرق", "Hide spoilers"],
  ],
  AniList: [
    ["المناقشات", "Discussions"],
    ["إخفاء الحرق", "Hide spoilers"],
  ],
};
export function Provider({ name }: { name: string }) {
  const n = useNova(),
    [dialog, setDialog] = useState(""),
    [input, setInput] = useState(""),
    [error, setError] = useState("");
  const tr = n.tr,
    linked = n.linked.includes(name),
    tracker = providers.slice(0, 5).includes(name);
  const keyProvider = ["TMDB", "Debrid", "IntroDB", "TheIntroDB"].includes(
    name,
  );
  const customLists: string[] = JSON.parse(n.prefs.lbLists || "[]");
  const connect = () => {
    if (n.scenario === "offline" || n.scenario === "error") {
      setError(
        tr("تعذّر الربط. أعد المحاولة.", "Could not connect. Try again."),
      );
      n.setScenario("ready");
      return;
    }
    n.setLinked((v) => [...new Set([...v, name])]);
    setDialog("");
  };
  return (
    <div className="page narrow">
      <Heading back title={name} />
      <Row
        title={
          linked
            ? tr("متصل بالحساب التجريبي", "Connected to demo account")
            : tr("غير مرتبط", "Disconnected")
        }
        icon={linked ? <Link /> : <Unlink />}
      />
      {name !== "AniSkip" && (
        <Btn primary onClick={() => setDialog(linked ? "unlink" : "link")}>
          {linked
            ? tr("فصل الخدمة", "Disconnect")
            : keyProvider
              ? tr("إعداد مفتاح تجريبي", "Configure sample key")
              : tr("ربط الخدمة", "Connect service")}
        </Btn>
      )}
      {name === "AniSkip" && (
        <p>
          {tr(
            "توقيتات تخطي متاحة للأعمال المطابقة.",
            "Skip timings are available for matching episodes.",
          )}
        </p>
      )}
      {name === "Letterboxd" && (
        <Select
          id="letterboxdMode"
          label={tr("وضع الاتصال", "Connection mode")}
          items={[
            ["public", "Public"],
            ["full", "Full"],
          ]}
        />
      )}
      {name === "Debrid" && (
        <Select
          id="debridProvider"
          label={tr("الخدمة", "Provider")}
          items={["Real-Debrid", "AllDebrid", "TorBox"].map((x) => [x, x])}
        />
      )}
      {name === "Simkl" && (
        <Select
          id="simklLanguage"
          label={tr("لغة اسم الأنمي", "Anime titles")}
          items={["English", "Romaji", "Native"].map((x) => [x, x])}
        />
      )}
      {name === "Trakt" && (
        <Select
          id="traktWindow"
          label={tr("فترة النشاط", "Activity window")}
          items={["30", "90", "180", "365"].map((x) => [
            x,
            x + tr(" يوم", " days"),
          ])}
        />
      )}
      {(features[name] || []).map((label) => (
        <Toggle
          key={label[1]}
          id={name + "." + label[1]}
          label={n.t(label)}
          initial
        />
      ))}
      {name === "MDBList" && (
        <Row
          title={tr("مفتاح شخصي", "Personal API key")}
          note={
            n.prefs.mdbPersonal
              ? tr("مفتاح تجريبي شخصي", "Personal sample key")
              : tr("المفتاح الافتراضي", "Built-in key")
          }
          onClick={() => setDialog("api")}
        />
      )}
      {tracker && (
        <>
          {["Trakt", "Simkl", "MDBList"].includes(name) && (
            <Toggle
              id={name + ".scrobble"}
              label={tr("إرسال تقدم المشاهدة", "Scrobble playback")}
              initial
            />
          )}
          {["AniList", "MyAnimeList"].includes(name) && (
            <Toggle
              id={name + ".progress"}
              label={tr("مزامنة تقدم الحلقات", "Sync episode progress")}
              initial
            />
          )}
          <Toggle
            id={name + ".sync"}
            label={tr("مزامنة المكتبة", "Sync library")}
            initial
          />
          {name !== "MDBList" && (
            <Toggle
              id={name + ".avatar"}
              label={tr("استخدام صورة الحساب", "Use service avatar")}
            />
          )}
          <Btn
            disabled={!linked}
            onClick={() =>
              n.setToast(tr("اكتملت مزامنة العيّنة", "Sample sync completed"))
            }
          >
            {tr("تحديث الآن", "Refresh now")}
          </Btn>
        </>
      )}
      {name === "Letterboxd" && (
        <>
          <Row
            title={tr("القوائم العامة المخصصة", "Custom public lists")}
            note={String(customLists.length)}
            onClick={() => {
              setInput("");
              setDialog("list");
            }}
          />
          <Btn onClick={() => n.go("settings/catalogs")}>
            {tr("ترتيب صفوف الرئيسية", "Home row order")}
          </Btn>
        </>
      )}
      {dialog && (
        <Modal title={name} onClose={() => setDialog("")}>
          {dialog === "unlink" ? (
            <Btn
              primary
              onClick={() => {
                n.setLinked((v) => v.filter((x) => x !== name));
                setDialog("");
              }}
            >
              {tr("تأكيد الفصل", "Confirm disconnect")}
            </Btn>
          ) : dialog === "list" ? (
            <>
              {customLists.map((x) => (
                <Row key={x} title={x}>
                  <Btn
                    onClick={() =>
                      n.pref(
                        "lbLists",
                        JSON.stringify(
                          customLists.filter((name) => x !== name),
                        ),
                      )
                    }
                  >
                    {tr("إزالة", "Remove")}
                  </Btn>
                </Row>
              ))}
              <label>
                {tr("اسم القائمة", "List name")}
                <input
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                />
              </label>
              <Btn
                disabled={!input.trim()}
                onClick={() => {
                  n.pref(
                    "lbLists",
                    JSON.stringify([
                      ...new Set([...customLists, input.trim()]),
                    ]),
                  );
                  setDialog("");
                }}
              >
                {tr("حفظ", "Save")}
              </Btn>
            </>
          ) : (
            <>
              {keyProvider || dialog === "api" ? (
                <>
                  <label>
                    {tr("مفتاح تجريبي للمعاينة", "Sample key for preview")}
                    <input readOnly value="nova-demo-key" />
                  </label>
                  {dialog === "api" && n.prefs.mdbPersonal && (
                    <Btn
                      onClick={() => {
                        n.pref("mdbPersonal", "");
                        setDialog("");
                      }}
                    >
                      {tr("إزالة المفتاح", "Remove key")}
                    </Btn>
                  )}
                </>
              ) : (
                <>
                  <p>
                    {name === "Letterboxd" && n.prefs.letterboxdMode !== "full"
                      ? tr("اسم مستخدم عام تجريبي", "Sample public username")
                      : tr(
                          "محاكاة تفويض محلي",
                          "Local authorization simulation",
                        )}
                  </p>
                  <code>
                    {name === "Letterboxd" ? "nova_sample" : "NOVA-DEMO"}
                  </code>
                </>
              )}
              {error && <p role="alert">{error}</p>}
              <Btn
                primary
                onClick={() => {
                  if (dialog === "api") {
                    n.pref("mdbPersonal", "sample");
                    setDialog("");
                  } else connect();
                }}
              >
                {keyProvider || dialog === "api"
                  ? tr("استخدام المفتاح التجريبي", "Use sample key")
                  : tr("إكمال الربط التجريبي", "Authorize sample account")}
              </Btn>
            </>
          )}
        </Modal>
      )}
    </div>
  );
}
export function Addon({ name }: { name: string }) {
  const n = useNova();
  return (
    <div className="page">
      <Heading back title={name} />
      <Row
        title={n.tr("موارد الإضافة", "Add-on resources")}
        note={n.tr(
          "كتالوجات · مصادر · ترجمة",
          "Catalogs · Streams · Subtitles",
        )}
      />
      <Btn
        onClick={() => {
          n.setInstalled((old) => old.filter((x) => x !== name));
          n.setCatalogs((old) => old.filter((x) => x !== name));
          n.go("settings/addons", true);
        }}
      >
        {n.tr("إزالة الإضافة", "Remove add-on")}
      </Btn>
    </div>
  );
}
