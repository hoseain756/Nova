import {
  ArrowUpRight,
  CalendarDays,
  ChevronRight,
  Compass,
  Layers3,
  LibraryBig,
  Radio,
  Search,
  SlidersHorizontal,
} from "lucide-react";
import { useEffect, useRef } from "react";
import { films, type Media } from "./data";
import { FilmHero } from "./FilmHero";
import { useNova } from "./session";
import {
  Art,
  Btn,
  Chips,
  Empty,
  Heading,
  NetworkState,
  Poster,
  Resume,
  Row,
  SavedButton,
} from "./ui";

function Rail({
  title,
  children,
  more,
}: {
  title: string;
  children: React.ReactNode;
  more?: () => void;
}) {
  const n = useNova();
  return (
    <section className="rail">
      <header>
        <h2>{title}</h2>
        {more && (
          <button className="text-btn" onClick={more}>
            {n.tr("عرض الكل", "View all")}{" "}
            <ChevronRight size={16} className="direction" />
          </button>
        )}
      </header>
      <div className="track">{children}</div>
    </section>
  );
}
function Hero({
  items,
  subheading = false,
}: {
  items: Media[];
  subheading?: boolean;
}) {
  const n = useNova();
  const selectionKey = n.profileId + "/" + n.route;
  const m =
    items.find((item) => item.id === n.featuredTitles[selectionKey]) ??
    items[0];
  if (!m) return null;
  return (
    <FilmHero
      media={m}
      subheading={subheading}
      selector={
        items.length > 1 && (
          <div
            className="film-hero-selector"
            role="group"
            aria-label={n.tr("اختيار العمل البارز", "Choose featured title")}
          >
            {items.map((item) => (
              <button
                key={item.id}
                type="button"
                aria-label={n.t(item.name)}
                title={n.t(item.name)}
                aria-pressed={item.id === m.id}
                onClick={() =>
                  n.setFeaturedTitles((titles) => ({
                    ...titles,
                    [selectionKey]: item.id,
                  }))
                }
              >
                <Art media={item} />
              </button>
            ))}
          </div>
        )
      }
    >
      <Btn primary onClick={() => n.go("title/" + m.id)}>
        {n.tr("تفاصيل العمل", "Explore title")}
        <ArrowUpRight size={18} className="direction" />
      </Btn>
      <SavedButton id={m.id} />
    </FilmHero>
  );
}
export function Home() {
  const n = useNova();
  const viewing = films.filter(
    (m) => n.lib.progress[m.id]?.pct > 0 && n.lib.progress[m.id].pct < 100,
  );
  const visible = films.filter(
    (m) =>
      !(n.prefs.hideAnime === "1" && m.type === "anime") &&
      !(
        n.prefs.hideWatchedInCatalogs === "1" &&
        n.lib.progress[m.id]?.pct === 100
      ),
  );
  return (
    <>
      {n.prefs.homeMode === "Classic" ? (
        <div className="sections">
          <Heading title={n.tr("الرئيسية", "Home")} />
        </div>
      ) : (
        <Hero items={visible.length ? visible.slice(0, 3) : [films[0]]} />
      )}
      <div className="sections">
        {viewing.length > 0 ? (
          <Rail
            title={n.tr("متابعة المشاهدة", "Continue watching")}
            more={() => {
              n.setLibTab("history");
              n.go("library");
            }}
          >
            {viewing.map((m) => (
              <Resume key={m.id} media={m} />
            ))}
          </Rail>
        ) : (
          <Row
            icon={<Compass />}
            title={n.tr("اعثر على أول عمل لك", "Find your first title")}
            onClick={() => n.go("discover")}
          />
        )}
        <NetworkState>
          {n.catalogs
            .filter((x) => n.prefs["hide." + x] !== "1")
            .map((catalog, i) => (
              <Rail
                key={catalog}
                title={
                  catalog === "Cinemeta"
                    ? n.tr("أفلام تستحق المشاهدة", "Films worth watching")
                    : catalog === "Anime"
                      ? n.tr("من عالم الأنمي", "From the world of anime")
                      : n.tr("مسلسلات للاكتشاف", "Series to discover")
                }
                more={() => {
                  n.setDiscovery({
                    ...n.discovery,
                    type:
                      catalog === "Anime"
                        ? "anime"
                        : catalog === "Cinemeta"
                          ? "film"
                          : "series",
                  });
                  n.go("discover");
                }}
              >
                {visible
                  .filter((m) =>
                    catalog === "Anime"
                      ? m.type === "anime"
                      : catalog === "Cinemeta"
                        ? m.type === "film"
                        : m.type === "series",
                  )
                  .map((m) => (
                    <Poster media={m} key={m.id} />
                  ))}
              </Rail>
            ))}
        </NetworkState>
        <Rail
          title={n.tr("من مجموعاتك", "From your collections")}
          more={() => {
            n.setLibTab("collections");
            n.go("library");
          }}
        >
          {n.lib.shelves.length ? (
            n.lib.shelves.map((s) => (
              <button
                className="shelf-card"
                key={s.id}
                onClick={() => n.go("collection/" + s.id)}
              >
                <div className="shelf-art">
                  {s.items.slice(0, 3).map((id) => (
                    <Art key={id} media={films.find((m) => m.id === id)!} />
                  ))}
                </div>
                <strong>{s.name}</strong>
                <small>
                  {s.items.length} {n.tr("أعمال", "titles")}
                </small>
              </button>
            ))
          ) : (
            <Btn
              onClick={() => {
                n.setLibTab("collections");
                n.go("library");
              }}
            >
              <LibraryBig />
              {n.tr("إنشاء مجموعة", "Create a collection")}
            </Btn>
          )}
        </Rail>
      </div>
    </>
  );
}
export function Browse({ mode }: { mode: "discover" | "anime" | "kids" }) {
  const n = useNova();
  const search = useRef<HTMLInputElement>(null);
  const { query: local, subset: season } = n.browseFilters[mode] || {
    query: "",
    subset: "all",
  };
  const setLocal = (query: string) =>
    n.setBrowseFilters((all) => ({
      ...all,
      [mode]: { query, subset: season },
    }));
  const setSeason = (subset: string) =>
    n.setBrowseFilters((all) => ({ ...all, [mode]: { query: local, subset } }));
  const isDiscover = mode === "discover",
    query = isDiscover ? n.discovery.query : local;
  const updateQuery = (v: string) =>
    isDiscover ? n.setDiscovery({ ...n.discovery, query: v }) : setLocal(v);
  useEffect(() => {
    if (n.route.endsWith("/search")) search.current?.focus();
  }, [n.route]);
  const list = films.filter(
    (m) =>
      (mode !== "kids" || m.family) &&
      (mode !== "anime" || m.type === "anime") &&
      (!isDiscover ||
        n.discovery.type === "all" ||
        m.type === n.discovery.type) &&
      m.name.some((name) => name.toLowerCase().includes(query.toLowerCase())) &&
      (season !== "saved" || n.lib.saved.includes(m.id)),
  );
  if (isDiscover && n.discovery.sort !== "popular")
    list.sort((a, b) =>
      n.discovery.sort === "year"
        ? b.year - a.year
        : n.discovery.sort === "name"
          ? n.t(a.name).localeCompare(n.t(b.name))
          : b.score - a.score,
    );
  return (
    <div className="sections">
      <Heading
        title={
          mode === "discover"
            ? n.tr("اكتشف", "Discover")
            : mode === "anime"
              ? n.tr("عالم الأنمي", "Anime")
              : n.tr("عالم الأطفال", "Kids")
        }
      />
      {!isDiscover && (
        <Hero
          subheading
          items={films.filter((m) =>
            mode === "kids" ? m.family : m.type === "anime",
          )}
        />
      )}
      {mode === "anime" && n.lib.progress.wind && (
        <Rail title={n.tr("متابعة المشاهدة", "Continue watching")}>
          <Resume media={films[3]} />
        </Rail>
      )}
      <label className="search">
        <Search />
        <input
          ref={search}
          value={query}
          onChange={(e) => updateQuery(e.target.value)}
          aria-label={n.tr("بحث", "Search")}
          placeholder={n.tr(
            "ابحث عن فيلم أو مسلسل",
            "Search movies and series",
          )}
        />
      </label>
      {isDiscover ? (
        <div className="filterbar">
          <Chips
            items={[
              ["all", n.tr("الكل", "All")],
              ["film", n.tr("أفلام", "Movies")],
              ["series", n.tr("مسلسلات", "Series")],
              ["anime", n.tr("أنمي", "Anime")],
            ]}
            value={n.discovery.type}
            onChange={(type) => n.setDiscovery({ ...n.discovery, type })}
          />
          <label className="select-inline">
            <SlidersHorizontal size={16} />
            <select
              aria-label={n.tr("ترتيب", "Sort")}
              value={n.discovery.sort}
              onChange={(e) =>
                n.setDiscovery({ ...n.discovery, sort: e.target.value })
              }
            >
              <option value="popular">{n.tr("الشائع", "Popular")}</option>
              <option value="score">{n.tr("التقييم", "Rating")}</option>
              <option value="year">{n.tr("السنة", "Year")}</option>
              <option value="name">{n.tr("العنوان", "Title")}</option>
            </select>
          </label>
        </div>
      ) : (
        <Chips
          items={[
            ["all", n.tr("الكل", "All")],
            ["saved", n.tr("المحفوظة", "Saved")],
          ]}
          value={season}
          onChange={setSeason}
        />
      )}
      <NetworkState>
        {list.length ? (
          <div className="grid">
            {list.map((m) => (
              <Poster key={m.id} media={m} />
            ))}
          </div>
        ) : (
          <Empty title={n.tr("لا توجد نتائج", "No results")}>
            <Btn
              onClick={() => {
                updateQuery("");
                setSeason("all");
                if (isDiscover)
                  n.setDiscovery({ query: "", sort: "popular", type: "all" });
              }}
            >
              {n.tr("مسح الفلاتر", "Clear filters")}
            </Btn>
          </Empty>
        )}
      </NetworkState>
      {isDiscover && (
        <>
          <Row
            title={n.tr("تقويم الحلقات", "Episode calendar")}
            icon={<CalendarDays />}
            onClick={() => n.go("calendar")}
          />
          <Row
            title={n.tr("البث المباشر", "Live TV")}
            icon={<Radio />}
            onClick={() => n.go("live")}
          />
        </>
      )}
      {mode === "anime" && (
        <Row
          icon={<Layers3 />}
          title={n.tr("تتبّع الأنمي", "Anime tracking")}
          onClick={() => n.go("title/wind")}
        />
      )}
    </div>
  );
}
