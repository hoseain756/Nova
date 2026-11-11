import {
  Baby,
  Compass,
  House,
  LibraryBig,
  Search,
  Sparkles,
  UserRound,
} from "lucide-react";
import { createRoot } from "react-dom/client";
import { AccountMenu, Auth, KidsGate, Onboarding, Profiles } from "./Account";
import { Browse, Home } from "./Browse";
import { dests, mediaById, type Dest } from "./data";
import { Calendar, LiveTV } from "./DiscoveryTools";
import {
  Collection,
  Downloads,
  Join,
  LibraryPage,
  MagnetFiles,
  NewCollection,
} from "./Library";
import { Context, useNova, useSession } from "./session";
import { Addon, Provider, Settings } from "./Settings";
import "./style.css";
import { Btn, Empty, IconBtn } from "./ui";
import { Details, Player, Sources } from "./Watch";
const icons = {
  home: House,
  discover: Compass,
  anime: Sparkles,
  library: LibraryBig,
  kids: Baby,
};
function Dock() {
  const n = useNova();
  return (
    <nav
      className={"dock " + (n.prefs.dock || "Classic")}
      aria-label={n.tr("التنقل الرئيسي", "Primary navigation")}
    >
      <img className="dock-brand" alt="" src="/brand/icon_red.svg" />
      {(Object.keys(dests) as Dest[]).map((id) => {
        const Icon = icons[id],
          active = n.tab === id;
        return (
          <button
            key={id}
            data-tab={id}
            title={n.t(dests[id])}
            aria-label={n.t(dests[id])}
            aria-current={active ? "page" : undefined}
            onClick={() => n.go(id)}
          >
            <Icon strokeWidth={active ? 2.5 : 1.7} />
            <span>{n.t(dests[id])}</span>
          </button>
        );
      })}
    </nav>
  );
}
function Screen() {
  const n = useNova();
  const [area, id, param, action] = n.route.split("/");
  const m = mediaById(id),
    ep = Math.max(1, Math.min(8, Number(param) || 1));
  switch (area) {
    case "onboarding":
      return <Onboarding />;
    case "home":
      return <Home />;
    case "discover":
    case "anime":
    case "kids":
      return <Browse mode={area} />;
    case "calendar":
      return <Calendar />;
    case "live":
      return <LiveTV />;
    case "title":
      if (m) return <Details m={m} />;
      break;
    case "sources":
      if (m) return <Sources m={m} ep={ep} download={action === "download"} />;
      break;
    case "player":
      if (m) return <Player m={m} ep={ep} live={action === "live"} />;
      break;
    case "library":
      return <LibraryPage />;
    case "new-list":
      return <NewCollection media={id} />;
    case "join":
      return <Join />;
    case "collection":
      return <Collection id={id} />;
    case "magnet-files":
      return <MagnetFiles />;
    case "downloads":
      return <Downloads />;
    case "account":
      return <AccountMenu />;
    case "profiles":
      return <Profiles mode={id} id={param} />;
    case "auth":
    case "welcome":
      return <Auth mode={id || "welcome"} />;
    case "settings":
      return <Settings section={id} />;
    case "addon":
      return <Addon name={decodeURIComponent(id)} />;
    case "service":
      return <Provider name={id} />;
  }
  return (
    <Empty title={n.tr("هذه الصفحة غير متاحة", "Page unavailable")}>
      <Btn onClick={() => n.go(n.kids ? "kids" : "home")}>
        {n.tr("عودة", "Return")}
      </Btn>
    </Empty>
  );
}
function App() {
  const n = useSession(),
    area = n.route.split("/")[0];
  const shell = area in dests,
    player = area === "player";
  return (
    <Context.Provider value={n}>
      <div
        className={shell ? "shell" : "standalone"}
        data-platform={n.platform}
      >
        {shell && (
          <>
            <Dock />
            <header className="top">
              <div className="brand">
                <img
                  className="wordmark"
                  src={
                    n.theme === "light"
                      ? "/brand/wordmark_ink.svg"
                      : "/brand/wordmark_white.svg"
                  }
                  alt="NOVA"
                />
              </div>
              <div className="actions">
                <IconBtn
                  label={n.tr("بحث", "Search")}
                  onClick={() => n.go("discover/search")}
                >
                  <Search />
                </IconBtn>
                <button
                  className={"avatar a" + n.profile.color}
                  title={n.tr("ملفي", "Profile")}
                  aria-label={n.tr("ملفي", "Profile")}
                  onClick={() => n.go("account")}
                >
                  {n.profile.name[0] || <UserRound />}
                </button>
              </div>
            </header>
          </>
        )}
        <main className={player ? "fullscreen" : ""} key={n.route}>
          <Screen />
        </main>
        {n.gate && <KidsGate />}
        {n.toast && (
          <div className="toast" role="status">
            {n.toast}
          </div>
        )}
      </div>
    </Context.Provider>
  );
}
createRoot(document.getElementById("root")!).render(<App />);
