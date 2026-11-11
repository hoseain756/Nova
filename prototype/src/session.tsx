import { createContext, useContext, useEffect, useRef, useState } from "react";
import {
  demoLibrary,
  emptyLibrary,
  initProfiles,
  kidSafe,
  sessionOptions,
  type Download,
  type Library,
  type Pair,
  type Profile,
} from "./data";
import definitions from "./preferences.json";
type Preferences = Record<string, string>;
const initial = sessionOptions();
export function useSession() {
  const initialRoute =
    decodeURI(location.hash.slice(1)) ||
    (initial.scenario === "onboarding" ? "onboarding" : "home");
  const [route, setRoute] = useState(initialRoute);
  const [en, setEn] = useState(initial.en);
  const [theme, setTheme] = useState(initial.theme);
  const [scenario, setScenario] = useState(initial.scenario);
  const [kids, setKids] = useState(initialRoute === "kids");
  const [gate, setGate] = useState("");
  const [parentPin, setParentPin] = useState("1234");
  const [profiles, setProfiles] = useState(initProfiles);
  const [profileId, setProfileId] = useState("noor");
  const [guest, setGuest] = useState(false);
  const [records, setRecords] = useState(() => {
    const seed =
      initial.scenario === "empty" || initial.scenario === "onboarding"
        ? emptyLibrary()
        : demoLibrary();
    return {
      private: {
        noor: { ...seed, shelves: seed.shelves.filter((s) => !s.shared) },
      } as Record<string, Library>,
      shared: seed.shelves
        .filter((s) => s.shared)
        .map((s) =>
          initial.scenario === "member"
            ? {
                ...s,
                role: "member" as const,
                invite: false,
                members: ["Mira"],
              }
            : s,
        ),
    };
  });
  const [downloads, setDownloads] = useState<Download[]>(
    initial.scenario === "empty"
      ? []
      : [
          {
            id: "fox-demo",
            media: "fox",
            ep: 1,
            progress: 100,
            status: "ready",
          },
        ],
  );
  const [prefs, setPrefs] = useState<Preferences>(() =>
    Object.fromEntries(definitions.map((row) => [row.key, row.value])),
  );
  const [toast, setToast] = useState("");
  const [discovery, setDiscovery] = useState({
    query: "",
    type: "all",
    sort: "popular",
  });
  const [libTab, setLibTab] = useState("saved");
  const [featuredTitles, setFeaturedTitles] = useState<Record<string, string>>(
    {},
  );
  const [libraryFilter, setLibraryFilter] = useState({
    query: "",
    sort: "recent",
  });
  const [browseFilters, setBrowseFilters] = useState<
    Record<string, { query: string; subset: string }>
  >({});
  const [installed, setInstalled] = useState(["Cinemeta", "Open Cinema"]);
  const [linked, setLinked] = useState<string[]>(["Trakt"]);
  const [catalogs, setCatalogs] = useState([
    "Cinemeta",
    "Open Cinema",
    "Anime",
  ]);
  const [defaultProfile, setDefaultProfile] = useState("noor");
  const stack = useRef([initialRoute]);
  const scroll = useRef(new Map<string, number>());
  const current = useRef(route);
  const kidsRef = useRef(kids);
  const fromTab = useRef(
    ["home", "discover", "anime", "library", "kids"].includes(
      initialRoute.split("/")[0],
    )
      ? initialRoute.split("/")[0]
      : "home",
  );
  const access = useRef<"open" | "signed-out" | "profile" | "new-profile">(
    initialRoute === "welcome" ? "signed-out" : "open",
  );
  function permitted(target: string) {
    if (
      access.current === "signed-out" &&
      !/^(auth\/|welcome$|onboarding$)/.test(target)
    )
      return "welcome";
    if (access.current === "new-profile" && target !== "profiles/new")
      return "profiles/new";
    if (access.current === "profile" && !target.startsWith("profiles"))
      return "profiles";
    return target;
  }
  const tr = (ar: string, enText: string) => (en ? enText : ar);
  const t = (pair: Pair) => pair[en ? 1 : 0];
  const privateData = records.private[profileId] ?? emptyLibrary();
  const lib = {
    ...privateData,
    shelves: [...privateData.shelves, ...records.shared],
  };
  const profile: Profile = profiles.find((p) => p.id === profileId) ?? {
    id: "",
    name: "NOVA",
    color: 0,
    pin: "",
  };
  function editLib(fn: (prev: Library) => Library) {
    setRecords((all) => {
      const previous = all.private[profileId] ?? emptyLibrary();
      const updated = fn({
        ...previous,
        shelves: [...previous.shelves, ...all.shared],
      });
      return {
        private: {
          ...all.private,
          [profileId]: {
            ...updated,
            shelves: updated.shelves.filter((s) => !s.shared),
          },
        },
        shared: updated.shelves.filter((s) => s.shared),
      };
    });
  }
  function pref(key: string, value: string) {
    setPrefs((prev) => ({ ...prev, [key]: value }));
  }
  function remember() {
    scroll.current.set(current.current, window.scrollY);
  }
  function show(target: string) {
    current.current = target;
    if (["home", "discover", "anime", "library", "kids"].includes(target))
      fromTab.current = target;
    if (target === "welcome") access.current = "signed-out";
    if (target === "kids") {
      kidsRef.current = true;
      setKids(true);
    }
    setRoute(target);
  }
  function go(target: string, replace = false, bypass = false) {
    if (target === "kids" && !parentPin && !bypass) {
      setGate("kids-setup");
      return;
    }
    if (kidsRef.current && !kidSafe(target) && !bypass) {
      setGate(target);
      return;
    }
    target = permitted(target);
    if (target === current.current) return;
    remember();
    if (replace) stack.current[stack.current.length - 1] = target;
    else stack.current.push(target);
    history[replace ? "replaceState" : "pushState"](
      { nova: stack.current.length - 1 },
      "",
      "#" + target,
    );
    show(target);
  }
  function back() {
    if (stack.current.length > 1) history.back();
    else go(kidsRef.current ? "kids" : fromTab.current, true);
  }
  function unlock(pin: string) {
    if (gate === "kids-setup") {
      if (!/^\d{4}$/.test(pin)) return false;
      setParentPin(pin);
      setGate("");
      go("kids", false, true);
      return true;
    }
    if (pin !== parentPin) return false;
    kidsRef.current = false;
    setKids(false);
    const target = gate;
    setGate("");
    go(target || "home", false, true);
    return true;
  }
  useEffect(() => {
    history.replaceState({ nova: 0 }, "", location.href);
    function onHistory() {
      const requested = decodeURI(location.hash.slice(1)) || "home";
      const target = permitted(requested);
      if (target !== requested)
        history.replaceState(history.state, "", "#" + target);
      if (kidsRef.current && !kidSafe(target)) {
        history.pushState(
          { nova: stack.current.length - 1 },
          "",
          "#" + current.current,
        );
        setGate(target);
        return;
      }
      remember();
      const index = history.state?.nova;
      if (typeof index === "number" && index < stack.current.length)
        stack.current = stack.current.slice(0, index + 1);
      else stack.current.push(target);
      show(target);
    }
    window.addEventListener("popstate", onHistory);
    return () => window.removeEventListener("popstate", onHistory);
  }, []);
  useEffect(() => {
    const id = requestAnimationFrame(() =>
      window.scrollTo(0, scroll.current.get(route) ?? 0),
    );
    return () => cancelAnimationFrame(id);
  }, [route]);
  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(() => setToast(""), 2600);
    return () => clearTimeout(id);
  }, [toast]);
  useEffect(() => {
    document.documentElement.lang = en ? "en" : "ar";
    document.documentElement.dir = en ? "ltr" : "rtl";
    document.documentElement.dataset.theme = theme;
    document.documentElement.dataset.phone = String(initial.phone);
    document.documentElement.dataset.solid = String(
      initial.solid || prefs.reduceTransparency === "1",
    );
    document.documentElement.dataset.motion =
      initial.reduced || prefs.reduceMotion === "1" ? "off" : "on";
    document.documentElement.style.setProperty(
      "--poster-radius",
      (prefs.posterRadius || 16) + "px",
    );
    document.documentElement.dataset.large = String(initial.large);
    document.documentElement.style.fontSize = initial.large ? "200%" : "";
  }, [en, theme, prefs]);
  useEffect(() => {
    if (!downloads.some((d) => d.status === "active")) return;
    const id = setInterval(
      () =>
        setDownloads((all) =>
          all.map((d) =>
            d.status !== "active"
              ? d
              : {
                  ...d,
                  progress: Math.min(100, d.progress + 15),
                  status: d.progress >= 85 ? "ready" : "active",
                },
          ),
        ),
      850,
    );
    return () => clearInterval(id);
  }, [downloads.length, downloads.some((d) => d.status === "active")]);
  function save(id: string) {
    editLib((l) => ({
      ...l,
      saved: l.saved.includes(id)
        ? l.saved.filter((x) => x !== id)
        : [...l.saved, id],
    }));
  }
  function checkpoint(id: string, ep: number, pct: number) {
    editLib((l) => ({ ...l, progress: { ...l.progress, [id]: { ep, pct } } }));
  }
  function enqueue(media: string, ep: number) {
    setDownloads((all) => [
      ...all,
      {
        id: crypto.randomUUID(),
        media,
        ep,
        progress: 0,
        status: scenario === "error" ? "failed" : "active",
      },
    ]);
  }
  function activate(id: string) {
    access.current = "open";
    setProfileId(id);
    setLibraryFilter({ query: "", sort: "recent" });
    setBrowseFilters({});
    scroll.current.clear();
    setDiscovery({ query: "", type: "all", sort: "popular" });
    setLibTab("saved");
    go("home", true);
  }
  function signIn() {
    access.current = "profile";
    setGuest(false);
    go("profiles", true);
  }
  function newAccount(asGuest: boolean) {
    access.current = "new-profile";
    setParentPin("");
    setGuest(asGuest);
    setRecords({ private: {}, shared: [] });
    setLinked([]);
    setProfiles([]);
    setProfileId("");
    setDefaultProfile("");
    go("profiles/new", true);
  }
  return {
    route,
    go,
    back,
    en,
    setEn,
    t,
    tr,
    theme,
    setTheme,
    scenario,
    setScenario,
    kids,
    gate,
    setGate,
    unlock,
    parentPin,
    setParentPin,
    profiles,
    setProfiles,
    profile,
    profileId,
    activate,
    defaultProfile,
    setDefaultProfile,
    guest,
    setGuest,
    lib,
    editLib,
    downloads,
    setDownloads,
    enqueue,
    prefs,
    pref,
    toast,
    setToast,
    save,
    checkpoint,
    discovery,
    setDiscovery,
    libTab,
    setLibTab,
    featuredTitles,
    setFeaturedTitles,
    newAccount,
    signIn,
    libraryFilter,
    setLibraryFilter,
    browseFilters,
    setBrowseFilters,
    installed,
    setInstalled,
    linked,
    setLinked,
    catalogs,
    setCatalogs,
    platform: initial.platform,
    tab: fromTab.current,
  };
}
export type Session = ReturnType<typeof useSession>;
export const Context = createContext<Session | null>(null);
export function useNova() {
  const s = useContext(Context);
  if (!s) throw Error("NOVA session missing");
  return s;
}
