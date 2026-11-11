import {
  ArrowLeft,
  Bookmark,
  Check,
  ChevronRight,
  CircleAlert,
  Inbox,
  Play,
  Star,
  WifiOff,
  X,
} from "lucide-react";
import { useEffect, useRef, type ReactNode } from "react";
import { type Media } from "./data";
import { useNova } from "./session";
export function Btn({
  children,
  onClick,
  primary = false,
  disabled = false,
}: {
  children: ReactNode;
  onClick?: () => void;
  primary?: boolean;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      className={primary ? "btn primary" : "btn secondary"}
      onClick={onClick}
      disabled={disabled}
    >
      {children}
    </button>
  );
}
export function IconBtn({
  label,
  children,
  onClick,
}: {
  label: string;
  children: ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      className="icon-btn"
      aria-label={label}
      title={label}
      onClick={onClick}
    >
      {children}
    </button>
  );
}
export function Heading({
  title,
  back = false,
  children,
}: {
  title: string;
  back?: boolean;
  children?: ReactNode;
}) {
  const n = useNova();
  return (
    <header className="heading">
      {back && (
        <IconBtn label={n.tr("رجوع", "Back")} onClick={n.back}>
          <ArrowLeft className="direction" />
        </IconBtn>
      )}
      <h1>{title}</h1>
      {children}
    </header>
  );
}
export function Row({
  title,
  note,
  children,
  onClick,
  icon,
}: {
  title: string;
  note?: string;
  children?: ReactNode;
  onClick?: () => void;
  icon?: ReactNode;
}) {
  const body = (
    <>
      {icon}
      <span className="row-copy">
        <strong>{title}</strong>
        {note && <small>{note}</small>}
      </span>
      {children}
      {onClick && <ChevronRight className="direction" size={18} />}
    </>
  );
  return onClick ? (
    <button className="row" onClick={onClick}>
      {body}
    </button>
  ) : (
    <div className="row">{body}</div>
  );
}
export function Modal({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const n = useNova();
  useEffect(() => {
    const dialog = ref.current;
    dialog?.showModal();
    return () => dialog?.close();
  }, []);
  return (
    <dialog
      ref={ref}
      onCancel={(e) => {
        e.preventDefault();
        onClose();
      }}
      aria-label={title}
      onClick={(e) => {
        if (e.target === ref.current) onClose();
      }}
    >
      <section>
        <header className="heading">
          <h2>{title}</h2>
          <IconBtn label={n.tr("إغلاق", "Close")} onClick={onClose}>
            <X />
          </IconBtn>
        </header>
        {children}
      </section>
    </dialog>
  );
}
export function Empty({
  title,
  children,
}: {
  title: string;
  children?: ReactNode;
}) {
  return (
    <div className="empty">
      <Inbox />
      <h3>{title}</h3>
      {children}
    </div>
  );
}
export function NetworkState({ children }: { children: ReactNode }) {
  const n = useNova();
  if (n.scenario === "loading")
    return (
      <div aria-busy="true" className="empty">
        <div className="skeleton" />
        <span>{n.tr("جارٍ التحميل…", "Loading…")}</span>
        <Btn onClick={() => n.setScenario("ready")}>
          {n.tr("إكمال المحاكاة", "Finish simulation")}
        </Btn>
      </div>
    );
  if (n.scenario === "error" || n.scenario === "offline")
    return (
      <div className="empty" role="status">
        {n.scenario === "offline" ? <WifiOff /> : <CircleAlert />}
        <h3>
          {n.scenario === "offline"
            ? n.tr("أنت غير متصل", "You’re offline")
            : n.tr("تعذّر تحميل المحتوى", "Couldn’t load this content")}
        </h3>
        <Btn onClick={() => n.setScenario("ready")}>
          {n.tr("إعادة المحاولة", "Retry")}
        </Btn>
      </div>
    );
  return <>{children}</>;
}
export function Art({
  media,
  className = "",
}: {
  media: Media;
  className?: string;
}) {
  return (
    <img
      className={"art " + className}
      src={"/art/" + media.id + ".jpg"}
      alt=""
      draggable={false}
    />
  );
}
export function Poster({ media }: { media: Media }) {
  const n = useNova();
  return (
    <button
      className="poster"
      aria-label={
        n.t(media.name) + " · " + n.t(media.genre) + " · " + media.year
      }
      onClick={() => n.go("title/" + media.id)}
    >
      <div className="poster-image">
        <Art media={media} />
        {n.prefs.showImdbBadge !== "0" && (
          <span className="rating">
            <Star size={12} />
            {media.score.toFixed(1)}
          </span>
        )}
        {n.lib.saved.includes(media.id) && (
          <Bookmark className="on-poster" size={17} fill="currentColor" />
        )}
      </div>
      {n.prefs.hidePosterTitles !== "1" && <strong>{n.t(media.name)}</strong>}
      <small>
        {n.t(media.genre)} · {media.year}
      </small>
    </button>
  );
}
export function Resume({ media }: { media: Media }) {
  const n = useNova(),
    p = n.lib.progress[media.id];
  if (!p) return null;
  return (
    <button
      className="resume"
      onClick={() => n.go("sources/" + media.id + "/" + p.ep)}
    >
      <div>
        <Art media={media} />
        <Play className="play-circle" />
        <i style={{ width: p.pct + "%" }} />
      </div>
      <strong>{n.t(media.name)}</strong>
      <small>
        {media.type === "film"
          ? n.t(media.genre)
          : n.tr("الحلقة ", "Episode ") + p.ep}{" "}
        · {Math.ceil(media.mins * (1 - p.pct / 100))}{" "}
        {n.tr("د متبقية", "min left")}
      </small>
    </button>
  );
}
export function SavedButton({ id }: { id: string }) {
  const n = useNova(),
    saved = n.lib.saved.includes(id);
  return (
    <Btn onClick={() => n.save(id)}>
      {saved ? <Check /> : <Bookmark />}
      {saved ? n.tr("محفوظ", "Saved") : n.tr("حفظ", "Save")}
    </Btn>
  );
}
export function Chips({
  items,
  value,
  onChange,
}: {
  items: [string, string][];
  value: string;
  onChange: (id: string) => void;
}) {
  return (
    <div className="chips">
      {items.map(([id, label]) => (
        <button
          key={id}
          aria-pressed={value === id}
          onClick={() => onChange(id)}
        >
          {label}
        </button>
      ))}
    </div>
  );
}
