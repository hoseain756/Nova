import {
  BookmarkPlus,
  Captions,
  Check,
  Download,
  FastForward,
  ListVideo,
  LockKeyhole,
  MoreHorizontal,
  Pause,
  Play,
  RefreshCw,
  Scan,
  Settings2,
  Share2,
  SkipForward,
  Star,
  Unlock,
  Volume2,
  X,
} from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { type Media } from "./data";
import { FilmHero } from "./FilmHero";
import { useNova } from "./session";
import {
  EpisodeActions,
  Recommendations,
  ReviewReader,
  Tracker,
} from "./TitleTools";
import {
  Art,
  Btn,
  Chips,
  Empty,
  Heading,
  IconBtn,
  Modal,
  NetworkState,
  Row,
  SavedButton,
} from "./ui";
export function Details({ m }: { m: Media }) {
  const n = useNova();
  const [season, setSeason] = useState(1),
    [panel, setPanel] = useState(""),
    [reveal, setReveal] = useState(false);
  const [actionEp, setActionEp] = useState(1);
  const p = n.lib.progress[m.id],
    ep = p?.ep || 1;
  const episodic = m.type !== "film",
    ended = p?.pct === 100;
  const play = (num: number) => n.go("sources/" + m.id + "/" + num);
  return (
    <article className="details">
      <FilmHero media={m} detail>
        <Btn primary onClick={() => play(ep)}>
          <Play />
          {p && !ended ? n.tr("متابعة", "Resume") : n.tr("شاهد", "Watch")}
          {episodic ? " · " + n.tr("الحلقة ", "Episode ") + ep : ""}
        </Btn>
        {!n.kids && (
          <>
            <SavedButton id={m.id} />
            <IconBtn
              label={n.tr("إضافة إلى مجموعة", "Add to collection")}
              onClick={() => setPanel("list")}
            >
              <BookmarkPlus />
            </IconBtn>
            <IconBtn
              label={n.tr("تنزيل", "Download")}
              onClick={() => n.go("sources/" + m.id + "/" + ep + "/download")}
            >
              <Download />
            </IconBtn>
          </>
        )}
      </FilmHero>
      <div className="detail-body">
        {episodic && (
          <section>
            <header className="heading">
              <h2>{n.tr("الحلقات", "Episodes")}</h2>
              <select
                aria-label={n.tr("الموسم", "Season")}
                value={season}
                onChange={(e) => setSeason(Number(e.target.value))}
              >
                {[1, 2].map((s) => (
                  <option key={s} value={s}>
                    {n.tr("الموسم ", "Season ") + s}
                  </option>
                ))}
              </select>
            </header>
            <div
              className={
                "episodes " + (n.prefs.episodesView === "List" ? "list" : "")
              }
            >
              {[1, 2, 3, 4].map((i) => {
                const e = i + (season - 1) * 4;
                return (
                  <div className="episode" key={e}>
                    <Row
                      icon={<ListVideo />}
                      title={n.tr("الحلقة ", "Episode ") + i}
                      note={
                        n.lib.watched[m.id]?.includes(e)
                          ? n.tr("تمت المشاهدة", "Watched")
                          : p?.ep === e
                            ? p.pct + "%"
                            : m.mins + n.tr(" دقيقة", " min")
                      }
                      onClick={() => play(e)}
                    />
                    <IconBtn
                      label={n.tr("إجراءات الحلقة ", "Episode options ") + i}
                      onClick={() => {
                        setActionEp(e);
                        setPanel("episode");
                      }}
                    >
                      <MoreHorizontal />
                    </IconBtn>
                  </div>
                );
              })}
            </div>
          </section>
        )}
        {!n.kids && (
          <>
            <h2>{n.tr("آراء المشاهدين", "Viewer reviews")}</h2>
            <Row
              icon={<Star />}
              title={n.tr("مراجعة من Mira", "Review by Mira")}
              note={
                reveal
                  ? n.tr(
                      "تغيّر النهاية معنى المشهد الأول.",
                      "The ending changes the meaning of the opening scene.",
                    )
                  : n.tr(
                      "تحتوي المراجعة على حرق",
                      "This review contains spoilers",
                    )
              }
              onClick={() => (reveal ? setPanel("review") : setReveal(true))}
            />
            <Row
              title={n.tr("تحديد كمُشاهَد", "Mark as watched")}
              icon={<Check />}
              note={ended ? n.tr("تمت المشاهدة", "Watched") : undefined}
              onClick={() => {
                n.checkpoint(m.id, ep, ended ? 0 : 100);
              }}
            />
          </>
        )}
        {!n.kids && (
          <div className="actions">
            <Btn onClick={() => setPanel("tracker")}>
              <Star />
              {n.tr("تتبّع وتقييم", "Track and rate")}
            </Btn>
            <Btn onClick={() => setPanel("share")}>
              <Share2 />
              {n.tr("مشاركة", "Share")}
            </Btn>
          </div>
        )}
        <Recommendations m={m} />
        {panel === "share" && (
          <Modal
            title={n.tr("مشاركة العمل", "Share title")}
            onClose={() => setPanel("")}
          >
            <label>
              {n.tr("رابط المعاينة", "Preview link")}
              <input
                readOnly
                value={location.href}
                onFocus={(e) => e.target.select()}
              />
            </label>
          </Modal>
        )}
        {panel === "episode" && (
          <EpisodeActions m={m} ep={actionEp} close={() => setPanel("")} />
        )}
        {panel === "tracker" && <Tracker m={m} close={() => setPanel("")} />}
        {panel === "review" && (
          <ReviewReader m={m} close={() => setPanel("")} />
        )}
        {panel === "list" && (
          <Modal
            title={n.tr("حفظ في مجموعة", "Save to collection")}
            onClose={() => setPanel("")}
          >
            {n.lib.shelves
              .filter((s) => s.edit)
              .map((s) => (
                <Row
                  key={s.id}
                  title={s.name}
                  note={
                    s.items.includes(m.id) ? n.tr("مضاف", "Added") : undefined
                  }
                  onClick={() => {
                    n.editLib((l) => ({
                      ...l,
                      shelves: l.shelves.map((c) =>
                        c.id === s.id
                          ? { ...c, items: [...new Set([...c.items, m.id])] }
                          : c,
                      ),
                    }));
                    setPanel("");
                  }}
                />
              ))}
            <Btn onClick={() => n.go("new-list/" + m.id)}>
              {n.tr("مجموعة جديدة", "New collection")}
            </Btn>
          </Modal>
        )}
      </div>
    </article>
  );
}
export function Sources({
  m,
  ep,
  download = false,
}: {
  m: Media;
  ep: number;
  download?: boolean;
}) {
  const n = useNova();
  const [query, setQuery] = useState(""),
    [busy, setBusy] = useState(true),
    [rev, setRev] = useState(0),
    [preparing, setPreparing] = useState(false);
  useEffect(() => {
    setBusy(true);
    const timer = setTimeout(() => setBusy(false), 350);
    return () => clearTimeout(timer);
  }, [rev]);
  const pick = () => {
    if (download) {
      n.enqueue(m.id, ep);
      n.go("downloads");
    } else n.go("player/" + m.id + "/" + ep);
  };
  useEffect(() => {
    if (!preparing) return;
    const timer = setTimeout(pick, 1100);
    return () => clearTimeout(timer);
  }, [preparing]);
  const choices = [
    ["1080p", "H.264 · 2.1 GB", "HTTP"],
    ["720p", "H.264 · 820 MB", "HTTP"],
    ["2160p", "HEVC · 7.4 GB", "P2P"],
  ];
  return (
    <div className="page">
      <Heading
        back
        title={
          download
            ? n.tr("مصادر التنزيل", "Download sources")
            : n.tr("اختيار المصدر", "Choose a source")
        }
      />
      <div className="mini-title">
        <Art media={m} />
        <div>
          <strong>{n.t(m.name)}</strong>
          <small>
            {m.type === "film"
              ? n.t(m.genre)
              : n.tr("الحلقة ", "Episode ") + ep}
          </small>
        </div>
      </div>
      <div className="filterbar">
        <input
          aria-label={n.tr("بحث في المصادر", "Search sources")}
          placeholder={n.tr("ابحث عن جودة أو صيغة", "Find a quality or format")}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <IconBtn
          label={n.tr("تحديث", "Refresh")}
          onClick={() => setRev(rev + 1)}
        >
          <RefreshCw />
        </IconBtn>
      </div>
      <NetworkState>
        {busy ? (
          <div role="status" className="skeleton" />
        ) : (
          choices
            .filter((r) =>
              r.join(" ").toLowerCase().includes(query.toLowerCase()),
            )
            .map(([q, info, protocol]) => {
              const disabled =
                protocol === "P2P" &&
                (n.prefs.p2pEnabled !== "1" ||
                  (download && n.platform === "ios"));
              return (
                <div className="source-row" key={q}>
                  <span className="quality">{q}</span>
                  <span>
                    <strong>
                      {protocol === "HTTP" ? "Open Cinema" : "Torrent"}
                    </strong>
                    <small>
                      {disabled
                        ? n.tr(
                            "مسار التورنت غير متاح",
                            "Torrent path unavailable",
                          )
                        : info + " · " + protocol}
                    </small>
                  </span>
                  <button
                    aria-label={(download ? "Download " : "Play ") + q}
                    disabled={disabled}
                    onClick={() =>
                      protocol === "P2P" ? setPreparing(true) : pick()
                    }
                  >
                    {download ? <Download /> : <Play />}
                  </button>
                </div>
              );
            })
        )}
        {!busy &&
          !choices.some((r) =>
            r.join(" ").toLowerCase().includes(query.toLowerCase()),
          ) && (
            <Empty
              title={n.tr("لا توجد مصادر مطابقة", "No matching sources")}
            />
          )}
      </NetworkState>
      {preparing && (
        <Modal
          title={n.tr("تجهيز التورنت", "Preparing torrent")}
          onClose={() => setPreparing(false)}
        >
          <p role="status">
            {n.tr(
              "جارٍ اختيار الملف وتهيئة البث…",
              "Selecting the file and preparing playback…",
            )}
          </p>
          <Btn onClick={() => setPreparing(false)}>
            {n.tr("إلغاء", "Cancel")}
          </Btn>
        </Modal>
      )}
    </div>
  );
}
export function Player({
  m,
  ep,
  live,
}: {
  m: Media;
  ep: number;
  live: boolean;
}) {
  const n = useNova();
  const existing = n.lib.progress[m.id];
  const start =
    n.prefs.resumePlayback !== "0" && existing?.ep === ep && existing.pct < 100
      ? existing.pct
      : 0;
  const [pct, setPct] = useState(start),
    [playing, setPlaying] = useState(!start || n.prefs.resumePrompt === "0"),
    [locked, setLocked] = useState(false);
  const [panel, setPanel] = useState(
      start && n.prefs.resumePrompt !== "0" ? "resume" : "",
    ),
    [speed, setSpeed] = useState("1"),
    [sub, setSub] = useState(
      n.prefs.subtitlesOffByDefault === "1" ? "off" : "ar",
    ),
    [audio, setAudio] = useState("original");
  const [rateHeld, setRateHeld] = useState(false),
    [level, setLevel] = useState(70),
    [bright, setBright] = useState(100);
  const automaticNext = useRef(true);
  const seek = (next: number) => {
    automaticNext.current = next < 94;
    setPct(Math.max(0, Math.min(100, next)));
  };
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const startPos = useRef({ x: 0, y: 0, held: false });
  const pctRef = useRef(pct);
  pctRef.current = pct;
  const save = useRef(n.checkpoint);
  save.current = n.checkpoint;
  useEffect(
    () => () => {
      if (timer.current) clearTimeout(timer.current);
      if (!live) save.current(m.id, ep, pctRef.current);
    },
    [m.id, ep, live],
  );
  useEffect(() => {
    if (!playing || panel || live) return;
    const clock = setInterval(
      () =>
        setPct((p) => Math.min(100, p + Number(rateHeld ? 2 : speed) * 0.5)),
      1000,
    );
    return () => clearInterval(clock);
  }, [playing, panel, speed, live, rateHeld]);
  useEffect(() => {
    if (pct < 100) return;
    setPlaying(false);
    if (
      m.type !== "film" &&
      ep < 8 &&
      n.prefs.autoPlayNextEpisode === "1" &&
      playing &&
      !locked &&
      !panel &&
      automaticNext.current
    )
      n.go("sources/" + m.id + "/" + (ep + 1));
  }, [pct]);
  const exit = () => {
    if (!live) save.current(m.id, ep, pct);
    n.back();
  };
  const chooseEpisode = (e: number) => {
    n.go(
      (n.prefs.autoSelectEpisodeSource === "1" ? "player/" : "sources/") +
        m.id +
        "/" +
        e,
    );
  };
  const tools: [string, string, React.ReactNode][] = [
    ["audio", n.tr("الصوت", "Audio"), <Volume2 />],
    ["subs", n.tr("الترجمة", "Subtitles"), <Captions />],
    ["speed", n.tr("السرعة", "Speed"), <FastForward />],
    ["sources", n.tr("المصادر", "Sources"), <Settings2 />],
  ];
  tools.push(["options", n.tr("إعدادات المشغّل", "Player settings"), <Scan />]);
  if (m.type !== "film")
    tools.push(["episodes", n.tr("الحلقات", "Episodes"), <ListVideo />]);
  return (
    <section className="player" data-fit={n.prefs.videoFill || "fit"}>
      <Art media={m} />
      <div
        className="player-filter"
        style={{ opacity: (100 - bright) / 100 + 0.18 }}
      />
      <div
        className="gesture"
        onPointerDown={(e) => {
          if (locked || panel) return;
          e.currentTarget.setPointerCapture(e.pointerId);
          startPos.current = { x: e.clientX, y: e.clientY, held: false };
          timer.current = setTimeout(() => {
            startPos.current.held = true;
            setRateHeld(true);
          }, 450);
        }}
        onPointerUp={(e) => {
          if (timer.current) clearTimeout(timer.current);
          setRateHeld(false);
          if (locked || panel || startPos.current.held) return;
          const dx = e.clientX - startPos.current.x,
            dy = e.clientY - startPos.current.y;
          if (Math.abs(dx) > 45 && Math.abs(dx) > Math.abs(dy) && !live)
            seek(pct + dx / 12);
          else if (Math.abs(dy) > 35) {
            const setter =
              startPos.current.x < window.innerWidth / 2 ? setBright : setLevel;
            setter((p) => Math.max(0, Math.min(100, p - dy / 4)));
          }
        }}
        onPointerCancel={() => {
          if (timer.current) clearTimeout(timer.current);
          setRateHeld(false);
        }}
      />
      <header>
        <IconBtn
          label={n.tr("خروج", "Exit")}
          onClick={() =>
            locked
              ? setLocked(false)
              : n.prefs.playerConfirmLeave === "1"
                ? setPanel("exit")
                : exit()
          }
        >
          {locked ? <Unlock /> : <X />}
        </IconBtn>
        <strong>{n.t(m.name)}</strong>
        {!locked && (
          <IconBtn label={n.tr("قفل", "Lock")} onClick={() => setLocked(true)}>
            <LockKeyhole />
          </IconBtn>
        )}
      </header>
      {!locked && (
        <>
          <button
            className="main-play"
            aria-label={
              playing ? n.tr("إيقاف مؤقت", "Pause") : n.tr("تشغيل", "Play")
            }
            onClick={() => setPlaying(!playing)}
          >
            {playing ? <Pause /> : <Play />}
          </button>
          <div className="player-bottom">
            {sub !== "off" && playing && (
              <p
                className="subtitle-preview"
                style={{
                  fontSize:
                    Math.min(
                      64,
                      Math.max(12, Number(n.prefs.subFontSize || 28)),
                    ) + "px",
                  transform:
                    "translateY(-" +
                    (100 - Number(n.prefs.subPos || 100)) +
                    "px)",
                  backgroundColor:
                    "rgba(0,0,0," + (n.prefs.subBackgroundOpacity || "0") + ")",
                  fontWeight: n.prefs.subFontBold === "1" ? 600 : 400,
                  color: n.prefs.subFontColor || "white",
                }}
              >
                {sub === "ar"
                  ? "كان الطريق أقرب مما تخيّلنا."
                  : "The way home was closer than we thought."}
              </p>
            )}
            {pct < 12 && !live && (
              <Btn onClick={() => setPct(13)}>
                <SkipForward />
                {n.tr("تخطي المقدمة", "Skip intro")}
              </Btn>
            )}
            {pct >= 94 && m.type !== "film" && ep < 8 && (
              <Btn onClick={() => chooseEpisode(ep + 1)}>
                {n.tr("الحلقة التالية", "Next episode")}
              </Btn>
            )}
            {live ? (
              <p>{n.tr("مباشر", "Live")}</p>
            ) : (
              <label className="timeline" dir={n.en ? "rtl" : "ltr"}>
                <span>{Math.round((pct * m.mins) / 100)}:00</span>
                <input
                  type="range"
                  aria-label={n.tr("موضع التشغيل", "Playback position")}
                  min="0"
                  max="100"
                  value={pct}
                  onChange={(e) => seek(Number(e.target.value))}
                />
                <span>{m.mins}:00</span>
              </label>
            )}
            <div className="actions">
              {tools.map(([key, label, icon]) => (
                <button key={key} onClick={() => setPanel(key)}>
                  {icon}
                  {label}
                </button>
              ))}
            </div>
          </div>
        </>
      )}
      {rateHeld && <output className="rate-hud">2×</output>}
      {panel && (
        <Modal
          title={
            tools.find((r) => r[0] === panel)?.[1] ||
            n.tr("المشاهدة", "Playback")
          }
          onClose={() => setPanel("")}
        >
          {panel === "resume" && (
            <>
              <p>
                {n.tr("متابعة من آخر موضع؟", "Resume from your last position?")}{" "}
                {Math.round((start * m.mins) / 100)}:00
              </p>
              <Btn
                primary
                onClick={() => {
                  setPlaying(true);
                  setPanel("");
                }}
              >
                {n.tr("متابعة", "Resume")}
              </Btn>
              <Btn
                onClick={() => {
                  setPct(0);
                  setPlaying(true);
                  setPanel("");
                }}
              >
                {n.tr("من البداية", "Start over")}
              </Btn>
            </>
          )}
          {panel === "exit" && (
            <Btn primary onClick={exit}>
              {n.tr("حفظ وخروج", "Save and exit")}
            </Btn>
          )}
          {panel === "options" && (
            <>
              <Chips
                value={n.prefs.videoFill || "fit"}
                onChange={(v) => n.pref("videoFill", v)}
                items={[
                  ["fit", n.tr("ملاءمة", "Fit")],
                  ["cover", n.tr("ملء", "Fill")],
                  ["stretch", n.tr("تمديد", "Stretch")],
                ]}
              />
              <label>
                {n.tr("السطوع", "Brightness")}
                <input
                  type="range"
                  value={bright}
                  onChange={(e) => setBright(Number(e.target.value))}
                />
              </label>
              <Row
                title={n.tr("نمط الترجمة", "Subtitle style")}
                onClick={() => setPanel("style")}
              />
            </>
          )}
          {panel === "audio" && (
            <>
              <Chips
                value={audio}
                onChange={setAudio}
                items={[
                  ["original", n.tr("الأصلي", "Original")],
                  ["ar", "العربية"],
                  ["en", "English"],
                ]}
              />
              <label>
                {n.tr("مستوى الصوت", "Volume")}
                <input
                  type="range"
                  value={level}
                  onChange={(e) => setLevel(Number(e.target.value))}
                />
              </label>
              <label>
                {n.tr("تأخير الصوت", "Audio delay")}
                <input
                  type="number"
                  step="10"
                  value={n.prefs.audioDelayMs || 0}
                  onChange={(e) => n.pref("audioDelayMs", e.target.value)}
                />
              </label>
            </>
          )}
          {panel === "subs" && (
            <>
              <Chips
                value={sub}
                onChange={setSub}
                items={[
                  ["off", n.tr("إيقاف", "Off")],
                  ["ar", "العربية"],
                  ["en", "English"],
                ]}
              />
              <Row
                title={n.tr("نمط الترجمة", "Subtitle style")}
                onClick={() => setPanel("style")}
              />
              <label>
                {n.tr("ملف ترجمة محلي", "Local subtitle file")}
                <input
                  type="file"
                  accept=".srt,.vtt,.ass"
                  onChange={(e) => {
                    if (e.target.files?.length) {
                      setSub("local");
                      n.setToast(e.target.files[0].name);
                    }
                  }}
                />
              </label>
            </>
          )}
          {panel === "style" && (
            <>
              <label>
                {n.tr("حجم الخط", "Font size")}
                <input
                  type="range"
                  min="12"
                  max="64"
                  value={n.prefs.subFontSize || 28}
                  onChange={(e) => n.pref("subFontSize", e.target.value)}
                />
              </label>
              <label>
                {n.tr("موضع الترجمة", "Subtitle position")}
                <input
                  type="range"
                  min="0"
                  max="100"
                  value={n.prefs.subPos || 100}
                  onChange={(e) => n.pref("subPos", e.target.value)}
                />
              </label>
              <label>
                {n.tr("نمط الملف", "Use file style")}
                <input
                  type="checkbox"
                  checked={n.prefs.subUseFileStyle === "1"}
                  onChange={(e) =>
                    n.pref("subUseFileStyle", e.target.checked ? "1" : "0")
                  }
                />
              </label>
              <label>
                {n.tr("لون النص", "Text color")}
                <input
                  type="color"
                  value={n.prefs.subFontColor || "#ffffff"}
                  onChange={(e) => n.pref("subFontColor", e.target.value)}
                />
              </label>
              <label>
                {n.tr("نص عريض", "Bold text")}
                <input
                  type="checkbox"
                  checked={n.prefs.subFontBold === "1"}
                  onChange={(e) =>
                    n.pref("subFontBold", e.target.checked ? "1" : "0")
                  }
                />
              </label>
              <label>
                {n.tr("تأخير الترجمة", "Subtitle delay")}
                <input
                  type="number"
                  step="10"
                  value={n.prefs.subtitleOffsetMs || 0}
                  onChange={(e) => n.pref("subtitleOffsetMs", e.target.value)}
                />
              </label>
            </>
          )}
          {panel === "speed" && (
            <Chips
              value={speed}
              onChange={setSpeed}
              items={["0.5", "1", "1.25", "1.5", "2"].map((x) => [x, x + "×"])}
            />
          )}
          {panel === "sources" && (
            <Btn onClick={() => n.go("sources/" + m.id + "/" + ep)}>
              {n.tr("تغيير المصدر", "Change source")}
            </Btn>
          )}
          {panel === "episodes" &&
            [1, 2, 3, 4, 5, 6, 7, 8].map((e) => (
              <Row
                key={e}
                title={n.tr("الحلقة ", "Episode ") + e}
                onClick={() => chooseEpisode(e)}
              />
            ))}
        </Modal>
      )}
    </section>
  );
}
