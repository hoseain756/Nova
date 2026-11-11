import {
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  Plus,
  Radio,
  RefreshCw,
  Trash2,
} from "lucide-react";
import { useState } from "react";
import { films } from "./data";
import { useNova } from "./session";
import {
  Btn,
  Chips,
  Empty,
  Heading,
  IconBtn,
  Modal,
  NetworkState,
  Row,
} from "./ui";
export function Calendar() {
  const n = useNova(),
    [week, setWeek] = useState(0),
    [day, setDay] = useState(0),
    [type, setType] = useState("all");
  const date = (offset: number) =>
    new Date(2026, 10, 9 + week * 7 + offset, 12);
  const fmt = (d: Date, opts: Intl.DateTimeFormatOptions) =>
    d.toLocaleDateString(n.en ? "en-GB" : "ar-SA-u-ca-gregory", opts);
  const sample =
    Math.abs(week) % 2 === 0
      ? [films[1], films[3], null, films[5], null, null, null]
      : [null, films[5], null, films[3], null, films[1], null];
  const entry = sample[day],
    visible = entry && (type === "all" || type === entry.type);
  return (
    <div className="page">
      <Heading back title={n.tr("تقويم الحلقات", "Episode calendar")} />
      <div className="heading">
        <IconBtn
          label={n.tr("الأسبوع السابق", "Previous week")}
          onClick={() => setWeek(week - 1)}
        >
          <ChevronLeft className="direction" />
        </IconBtn>
        <h2>
          {fmt(date(0), { day: "numeric", month: "long" })} –{" "}
          {fmt(date(6), { day: "numeric", month: "long" })}
        </h2>
        <IconBtn
          label={n.tr("الأسبوع التالي", "Next week")}
          onClick={() => setWeek(week + 1)}
        >
          <ChevronRight className="direction" />
        </IconBtn>
      </div>
      <Chips
        value={String(day)}
        onChange={(v) => setDay(Number(v))}
        items={Array.from({ length: 7 }, (_, i) => [
          String(i),
          fmt(date(i), { weekday: "short", day: "numeric" }),
        ])}
      />
      <Chips
        value={type}
        onChange={setType}
        items={[
          ["all", n.tr("الكل", "All")],
          ["series", n.tr("مسلسلات", "Series")],
          ["anime", n.tr("أنمي", "Anime")],
        ]}
      />
      <NetworkState>
        {visible ? (
          <Row
            icon={<CalendarDays />}
            title={n.t(entry.name)}
            note={n.tr("الحلقة ٤ · ٢٠:٠٠", "Episode 4 · 20:00")}
            onClick={() => n.go("title/" + entry.id)}
          />
        ) : (
          <Empty
            title={n.tr("لا توجد حلقات مجدولة", "No scheduled episodes")}
          />
        )}
      </NetworkState>
    </div>
  );
}
type Playlist = { name: string; url: string; epg: string };
export function LiveTV() {
  const n = useNova(),
    [list, setList] = useState("all"),
    [query, setQuery] = useState(""),
    [panel, setPanel] = useState(""),
    [name, setName] = useState(""),
    [url, setUrl] = useState(""),
    [epg, setEpg] = useState("");
  const saved: Playlist[] = JSON.parse(n.prefs.playlists || "[]"),
    base = n.tr("قناة الطبيعة", "Nature channel");
  const matches = [
    { name: base, list: "base" },
    ...saved.map((s) => ({ name: s.name, list: s.name })),
  ].filter(
    (c) =>
      (list === "all" || list === c.list) &&
      c.name.toLowerCase().includes(query.toLowerCase()),
  );
  function save(v: Playlist[]) {
    n.pref("playlists", JSON.stringify(v));
  }
  return (
    <div className="page">
      <Heading back title={n.tr("البث المباشر", "Live TV")}>
        <IconBtn
          label={n.tr("تحديث", "Refresh")}
          onClick={() => {
            n.setScenario("ready");
            n.setToast(n.tr("تم تحديث القنوات", "Channels refreshed"));
          }}
        >
          <RefreshCw />
        </IconBtn>
      </Heading>
      <div className="actions">
        <Btn
          onClick={() => {
            setName("");
            setUrl("");
            setEpg("");
            setPanel("add");
          }}
        >
          <Plus />
          {n.tr("إضافة قائمة بث", "Add playlist")}
        </Btn>
      </div>
      <label>
        {n.tr("البحث عن قناة", "Find a channel")}
        <input value={query} onChange={(e) => setQuery(e.target.value)} />
      </label>
      <Chips
        value={list}
        onChange={setList}
        items={[
          ["all", n.tr("الكل", "All")],
          ["base", n.tr("طبيعة", "Nature")],
          ...saved.map((x) => [x.name, x.name] as [string, string]),
        ]}
      />
      <NetworkState>
        {!matches.length && (
          <Empty title={n.tr("لا توجد قنوات", "No channels")} />
        )}{" "}
        {matches.map((c) => (
          <div className="episode" key={c.list}>
            <Row
              title={c.name}
              note={n.tr("بث تجريبي", "Demo broadcast")}
              icon={<Radio />}
              onClick={() => n.go("player/fox/1/live")}
            />
            {c.list !== "base" && (
              <IconBtn
                label={n.tr("إزالة القائمة", "Remove playlist")}
                onClick={() => setPanel(c.name)}
              >
                <Trash2 />
              </IconBtn>
            )}
          </div>
        ))}
      </NetworkState>
      {panel && (
        <Modal
          title={
            panel === "add"
              ? n.tr("قائمة بث جديدة", "New playlist")
              : n.tr("إزالة القائمة؟", "Remove playlist?")
          }
          onClose={() => setPanel("")}
        >
          {panel === "add" ? (
            <form
              onSubmit={(e) => {
                e.preventDefault();
                if (!name.trim()) return;
                save([
                  ...saved.filter((x) => x.name !== name.trim()),
                  { name: name.trim(), url, epg },
                ]);
                setPanel("");
              }}
            >
              <label>
                {n.tr("الاسم", "Name")}
                <input
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </label>
              <label>
                M3U URL
                <input
                  type="url"
                  required
                  value={url}
                  placeholder="https://example.test/nature.m3u"
                  onChange={(e) => setUrl(e.target.value)}
                />
              </label>
              <label>
                EPG URL
                <input
                  type="url"
                  value={epg}
                  onChange={(e) => setEpg(e.target.value)}
                />
              </label>
              <button className="btn primary">{n.tr("إضافة", "Add")}</button>
            </form>
          ) : (
            <Btn
              onClick={() => {
                save(saved.filter((x) => x.name !== panel));
                setList("all");
                setPanel("");
              }}
            >
              {n.tr("إزالة", "Remove")}
            </Btn>
          )}
        </Modal>
      )}
    </div>
  );
}
