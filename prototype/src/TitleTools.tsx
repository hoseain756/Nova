import { CheckCheck, Download, ListChecks, Star } from "lucide-react";
import { useState } from "react";
import { films, type Media } from "./data";
import { useNova } from "./session";
import { Btn, Chips, Modal, Poster, Row } from "./ui";

export function EpisodeActions({
  m,
  ep,
  close,
}: {
  m: Media;
  ep: number;
  close: () => void;
}) {
  const n = useNova();
  function mark(through: boolean) {
    n.editLib((l) => {
      const previous = l.watched[m.id] || [];
      const extras = through
        ? Array.from({ length: ep }, (_, i) => i + 1)
        : [ep];
      return {
        ...l,
        progress: { ...l.progress, [m.id]: { ep, pct: 100 } },
        watched: {
          ...l.watched,
          [m.id]: [...new Set([...previous, ...extras])],
        },
      };
    });
    close();
  }
  return (
    <Modal
      title={n.tr("إجراءات الحلقة ", "Episode actions · ") + ep}
      onClose={close}
    >
      <Row
        icon={<CheckCheck />}
        title={n.tr("تحديد الحلقة كمشاهدة", "Mark episode watched")}
        onClick={() => mark(false)}
      />
      <Row
        icon={<ListChecks />}
        title={n.tr(
          "مشاهَد حتى هذه الحلقة",
          "Mark watched through this episode",
        )}
        onClick={() => mark(true)}
      />
      {!n.kids && (
        <Row
          icon={<Download />}
          title={n.tr("تنزيل الحلقة", "Download episode")}
          onClick={() => n.go("sources/" + m.id + "/" + ep + "/download")}
        />
      )}
    </Modal>
  );
}
export function Tracker({ m, close }: { m: Media; close: () => void }) {
  const n = useNova();
  const original = n.lib.tracking[m.id];
  const [status, setStatus] = useState(original?.status || "planning"),
    [count, setCount] = useState(original?.count || 0),
    [score, setScore] = useState(original?.score || 0);
  const targets = (
    m.type === "anime"
      ? ["AniList", "MyAnimeList", "Simkl"]
      : ["Simkl", "Trakt"]
  ).filter((x) => n.linked.includes(x));
  return (
    <Modal title={n.tr("تتبّع العمل", "Track title")} onClose={close}>
      {targets.length ? (
        <>
          <p className="muted">{targets.join(" · ")}</p>
          <Chips
            value={status}
            onChange={setStatus}
            items={[
              ["planning", n.tr("للمشاهدة", "Planning")],
              ["watching", n.tr("قيد المتابعة", "Watching")],
              ["complete", n.tr("مكتمل", "Completed")],
              ["paused", n.tr("متوقف", "Paused")],
              ["dropped", n.tr("متروك", "Dropped")],
            ]}
          />
          {m.type !== "film" && (
            <label>
              {n.tr("الحلقات المشاهدة", "Episodes watched")}
              <input
                type="number"
                min={0}
                max={8}
                value={count}
                onChange={(e) =>
                  setCount(Math.max(0, Math.min(8, Number(e.target.value))))
                }
              />
            </label>
          )}
          <label>
            {n.tr("تقييمي", "My rating")} · {score}/10
            <input
              type="range"
              min={0}
              max={10}
              value={score}
              onChange={(e) => setScore(Number(e.target.value))}
            />
          </label>
          <Btn
            primary
            onClick={() => {
              n.editLib((l) => ({
                ...l,
                tracking: { ...l.tracking, [m.id]: { status, count, score } },
              }));
              close();
            }}
          >
            {n.tr("حفظ", "Save")}
          </Btn>
          {original?.status === "planning" &&
            !original.count &&
            !original.score && (
              <Btn
                onClick={() => {
                  n.editLib((l) => {
                    const tracking = { ...l.tracking };
                    delete tracking[m.id];
                    return { ...l, tracking };
                  });
                  close();
                }}
              >
                {n.tr("إزالة من التتبّع", "Remove tracking entry")}
              </Btn>
            )}
        </>
      ) : (
        <>
          <p>
            {n.tr(
              "اربط خدمة لتتبّع هذا العمل.",
              "Connect a service to track this title.",
            )}
          </p>
          <Btn
            onClick={() =>
              n.go("service/" + (m.type === "anime" ? "AniList" : "Simkl"))
            }
          >
            {n.tr("ربط خدمة", "Connect a service")}
          </Btn>
        </>
      )}
    </Modal>
  );
}
export function Recommendations({ m }: { m: Media }) {
  const n = useNova();
  return (
    <section className="rail">
      <header>
        <h2>{n.tr("قد يعجبك أيضًا", "More like this")}</h2>
      </header>
      <div className="track">
        {films
          .filter((x) => x.id !== m.id && (!n.kids || x.family))
          .slice(0, 3)
          .map((x) => (
            <Poster key={x.id} media={x} />
          ))}
      </div>
    </section>
  );
}
export function ReviewReader({ m, close }: { m: Media; close: () => void }) {
  const n = useNova();
  return (
    <Modal title={n.t(m.name)} onClose={close}>
      <p className="score">
        <Star /> Mira · 4/5
      </p>
      <p>
        {n.tr(
          "تغيّر النهاية معنى المشهد الأول. أعجبني كيف عادت الصورة الأخيرة إلى المكان نفسه بعد أن عرفنا قصة الشخصيات.",
          "The ending changes the meaning of the opening scene. I loved how the final shot returns to the same place after we have come to know the characters.",
        )}
      </p>
    </Modal>
  );
}
