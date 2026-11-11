import {
  ArrowDownToLine,
  Check,
  Clipboard,
  Download,
  FolderPlus,
  Magnet,
  Pencil,
  Plus,
  Search,
  Trash2,
  UsersRound,
} from "lucide-react";
import { useState } from "react";
import { films, mediaById, type Shelf } from "./data";
import { useNova } from "./session";
import {
  Art,
  Btn,
  Chips,
  Empty,
  Heading,
  IconBtn,
  Modal,
  Poster,
  Row,
} from "./ui";

export function LibraryPage() {
  const n = useNova();
  const { query, sort } = n.libraryFilter;
  const setQuery = (query: string) =>
    n.setLibraryFilter((old) => ({ ...old, query }));
  const setSort = (sort: string) =>
    n.setLibraryFilter((old) => ({ ...old, sort }));
  const [magnet, setMagnet] = useState(false),
    [input, setInput] = useState("");
  const saved = n.libTab === "saved";
  const ids = saved
    ? n.lib.saved
    : Object.keys(n.lib.progress).filter((id) => n.lib.progress[id].pct > 0);
  const list = ids
    .map(mediaById)
    .filter((x) => !!x)
    .filter((m) => n.t(m.name).toLowerCase().includes(query.toLowerCase()));
  if (sort === "name")
    list.sort((a, b) => n.t(a.name).localeCompare(n.t(b.name)));
  else if (sort === "year") list.sort((a, b) => b.year - a.year);
  return (
    <div className="sections">
      <Heading title={n.tr("مكتبتي", "My Library")}>
        <IconBtn
          label={n.tr("التنزيلات", "Downloads")}
          onClick={() => n.go("downloads")}
        >
          <Download />
        </IconBtn>
        <IconBtn label="Magnet" onClick={() => setMagnet(true)}>
          <Magnet />
        </IconBtn>
      </Heading>
      <Chips
        value={n.libTab}
        onChange={n.setLibTab}
        items={[
          ["saved", n.tr("قائمة المشاهدة", "Watchlist")],
          ["history", n.tr("السجل", "History")],
          ["collections", n.tr("المجموعات", "Collections")],
        ]}
      />
      {n.libTab === "collections" ? (
        <>
          <div className="actions">
            <Btn primary onClick={() => n.go("new-list")}>
              <FolderPlus />
              {n.tr("مجموعة جديدة", "New collection")}
            </Btn>
            <Btn onClick={() => n.go("join")}>
              <UsersRound />
              {n.tr("انضمام بدعوة", "Join by invitation")}
            </Btn>
          </div>
          {n.lib.shelves.map((s) => (
            <Row
              key={s.id}
              title={s.name}
              note={
                (s.shared
                  ? n.tr("مشتركة", "Shared")
                  : n.tr("خاصة", "Personal")) +
                " · " +
                s.items.length
              }
              icon={<UsersRound />}
              onClick={() => n.go("collection/" + s.id)}
            />
          ))}
        </>
      ) : (
        <>
          <div className="filterbar">
            <label className="search">
              <Search />
              <input
                placeholder={n.tr("بحث في مكتبتي", "Search my library")}
                value={query}
                onChange={(e) => setQuery(e.target.value)}
              />
            </label>
            <select
              aria-label={n.tr("ترتيب", "Sort")}
              value={sort}
              onChange={(e) => setSort(e.target.value)}
            >
              {[
                ["recent", n.tr("الأحدث", "Recent")],
                ["name", n.tr("العنوان", "Title")],
                ["year", n.tr("السنة", "Year")],
              ].map(([v, label]) => (
                <option value={v} key={v}>
                  {label}
                </option>
              ))}
            </select>
          </div>
          {list.length ? (
            <div className="grid">
              {list.map((m) => (
                <Poster key={m.id} media={m} />
              ))}
            </div>
          ) : (
            <Empty title={n.tr("لا توجد أعمال هنا بعد", "No titles here yet")}>
              <Btn onClick={() => n.go("discover")}>
                {n.tr("اكتشف أعمالًا", "Explore titles")}
              </Btn>
            </Empty>
          )}
        </>
      )}
      {magnet && (
        <Modal
          title={n.tr("فتح رابط Magnet", "Open Magnet link")}
          onClose={() => setMagnet(false)}
        >
          <p>
            {n.tr(
              "اختر رابط العيّنة لتجربة تحديد الملف.",
              "Use the sample link to try file selection.",
            )}
          </p>
          <label>
            Magnet URI
            <input value={input} onChange={(e) => setInput(e.target.value)} />
          </label>
          <Btn
            onClick={() =>
              setInput(
                "magnet:?xt=urn:btih:0123456789012345678901234567890123456789",
              )
            }
          >
            {n.tr("استخدام عيّنة", "Use sample")}
          </Btn>
          <Btn
            primary
            disabled={!/^magnet:\?xt=urn:btih:[a-z0-9]{32,40}/i.test(input)}
            onClick={() => n.go("magnet-files")}
          >
            {n.tr("عرض الملفات", "Choose file")}
          </Btn>
        </Modal>
      )}
    </div>
  );
}
export function NewCollection({ media }: { media?: string }) {
  const n = useNova(),
    [name, setName] = useState(""),
    [description, setDescription] = useState(""),
    [shared, setShared] = useState(false);
  return (
    <div className="page narrow">
      <Heading back title={n.tr("مجموعة جديدة", "New collection")} />
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (!name.trim()) return;
          const s: Shelf = {
            id: crypto.randomUUID(),
            name: name.trim(),
            description: description.trim(),
            shared,
            items: media && mediaById(media) ? [media] : [],
            role: "owner",
            edit: true,
            invite: true,
            token: 1,
            members: [],
          };
          n.editLib((l) => ({ ...l, shelves: [...l.shelves, s] }));
          n.go("collection/" + s.id, true);
        }}
      >
        <label>
          {n.tr("اسم المجموعة", "Collection name")}
          <input
            required
            maxLength={80}
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </label>
        <label>
          {n.tr("الوصف", "Description")}
          <textarea
            maxLength={400}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </label>
        <label className="check">
          <input
            type="checkbox"
            checked={shared}
            onChange={(e) => setShared(e.target.checked)}
          />
          {n.tr("مشاركة مع آخرين", "Share with others")}
        </label>
        <button className="btn primary" disabled={!name.trim()}>
          {n.tr("إنشاء", "Create")}
        </button>
      </form>
    </div>
  );
}
export function Join() {
  const n = useNova(),
    [token, setToken] = useState(""),
    [error, setError] = useState(false);
  function join() {
    if (
      token !== "NOVA-FRIENDS" &&
      !n.lib.shelves.some((s) => s.shared && token === s.id + "-" + s.token)
    ) {
      setError(true);
      return;
    }
    const existing = n.lib.shelves.find(
      (s) =>
        token === s.id + "-" + s.token ||
        (token === "NOVA-FRIENDS" && s.id === "friends"),
    );
    if (existing) {
      n.go("collection/" + existing.id, true);
      return;
    }
    n.editLib((l) => ({
      ...l,
      shelves: [
        ...l.shelves,
        {
          id: "friends",
          name: "Film club",
          shared: true,
          items: ["fox", "wind"],
          role: "member",
          edit: true,
          invite: false,
          members: ["Mira"],
          token: 1,
        },
      ],
    }));
    n.go("collection/friends", true);
  }
  return (
    <div className="page narrow">
      <Heading back title={n.tr("قبول دعوة", "Accept invitation")} />
      <label>
        {n.tr("رمز الدعوة", "Invitation code")}
        <input
          value={token}
          onChange={(e) => {
            setToken(e.target.value);
            setError(false);
          }}
        />
      </label>
      <small>{n.tr("رمز تجريبي", "Demo code")} · NOVA-FRIENDS</small>
      {error && (
        <p role="alert">
          {n.tr("هذه الدعوة غير صالحة", "This invitation is invalid")}
        </p>
      )}
      <Btn primary onClick={join}>
        {n.tr("انضمام", "Join")}
      </Btn>
    </div>
  );
}
export function Collection({ id }: { id: string }) {
  const n = useNova(),
    s = n.lib.shelves.find((x) => x.id === id);
  const [panel, setPanel] = useState(""),
    [name, setName] = useState(""),
    [description, setDescription] = useState(""),
    [item, setItem] = useState(""),
    [note, setNote] = useState(""),
    [error, setError] = useState(false);
  if (!s)
    return (
      <Empty title={n.tr("المجموعة غير متاحة", "Collection unavailable")}>
        <Btn onClick={() => n.go("library")}>
          {n.tr("مكتبتي", "My Library")}
        </Btn>
      </Empty>
    );
  const owner = s.role === "owner";
  const update = (fn: (old: Shelf) => Shelf) =>
    n.editLib((l) => ({
      ...l,
      shelves: l.shelves.map((x) => (x.id === id ? fn(x) : x)),
    }));
  function mutate(fn: (old: Shelf) => Shelf) {
    if (n.scenario === "conflict") {
      setError(true);
      return;
    }
    update(fn);
    setPanel("");
  }
  return (
    <div className="page">
      <Heading back title={s.name} />
      <p className="muted">
        {s.shared
          ? n.tr("مجموعة مشتركة", "Shared collection")
          : n.tr("قائمة خاصة", "Personal list")}{" "}
        · {s.items.length} {n.tr("أعمال", "titles")}
      </p>
      {s.description && <p>{s.description}</p>}
      <div className="actions">
        {s.edit && (
          <Btn primary onClick={() => setPanel("add")}>
            <Plus />
            {n.tr("إضافة عمل", "Add title")}
          </Btn>
        )}
        {s.role === "owner" && (
          <Btn
            onClick={() => {
              setName(s.name);
              setDescription(s.description || "");
              setPanel("rename");
            }}
          >
            <Pencil />
            {n.tr("تعديل الاسم", "Rename")}
          </Btn>
        )}
        {s.shared && (
          <Btn onClick={() => setPanel("members")}>
            <UsersRound />
            {n.tr("الأعضاء والدعوات", "Members & invitations")}
          </Btn>
        )}
        <IconBtn
          label={
            s.role === "owner"
              ? n.tr("حذف المجموعة", "Delete collection")
              : n.tr("مغادرة", "Leave")
          }
          onClick={() => setPanel("delete")}
        >
          <Trash2 />
        </IconBtn>
      </div>
      <div className="grid">
        {s.items.map((id) => {
          const m = mediaById(id);
          return (
            m && (
              <div key={id}>
                <Poster media={m} />
                {s.notes?.[id] && <p>{s.notes[id]}</p>}
                {owner && (
                  <button
                    className="text-btn"
                    onClick={() => {
                      setItem(id);
                      setNote(s.notes?.[id] || "");
                      setPanel("note");
                    }}
                  >
                    {n.tr("ملاحظة", "Item note")}
                  </button>
                )}
                {s.role === "owner" && (
                  <button
                    className="text-btn"
                    onClick={() =>
                      mutate((c) => ({
                        ...c,
                        items: c.items.filter((x) => x !== id),
                      }))
                    }
                  >
                    {n.tr("إزالة", "Remove")}
                  </button>
                )}
              </div>
            )
          );
        })}
      </div>
      {panel && (
        <Modal
          title={
            panel === "add"
              ? n.tr("إضافة عمل", "Add title")
              : panel === "members"
                ? n.tr("إدارة المشاركة", "Manage sharing")
                : s.name
          }
          onClose={() => setPanel("")}
        >
          {panel === "add" &&
            films.map((m) => (
              <Row
                key={m.id}
                title={n.t(m.name)}
                icon={s.items.includes(m.id) ? <Check /> : <Plus />}
                onClick={() =>
                  mutate((c) => ({
                    ...c,
                    items: [...new Set([...c.items, m.id])],
                  }))
                }
              />
            ))}
          {panel === "note" && (
            <>
              <label>
                {n.tr("ملاحظة على العمل", "Item note")}
                <textarea
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                />
              </label>
              <Btn
                primary
                onClick={() =>
                  mutate((c) => ({ ...c, notes: { ...c.notes, [item]: note } }))
                }
              >
                {n.tr("حفظ", "Save")}
              </Btn>
            </>
          )}
          {panel === "rename" && (
            <>
              <label>
                {n.tr("الاسم", "Name")}
                <input value={name} onChange={(e) => setName(e.target.value)} />
              </label>
              <label>
                {n.tr("الوصف", "Description")}
                <textarea
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                />
              </label>
              <Btn
                primary
                disabled={!name.trim()}
                onClick={() =>
                  mutate((c) => ({
                    ...c,
                    name: name.trim(),
                    description: description.trim(),
                  }))
                }
              >
                {n.tr("حفظ", "Save")}
              </Btn>
            </>
          )}
          {panel === "members" && (
            <>
              <Row
                title={s.role === "owner" ? n.profile.name : "Mira"}
                note={n.tr("المالك", "Owner")}
              />
              {s.members
                .filter((x) => s.role === "owner" || x !== "Mira")
                .map((member) => (
                  <Row key={member} title={member} note={n.tr("عضو", "Member")}>
                    {s.role === "owner" && (
                      <IconBtn
                        label={n.tr("إزالة العضو", "Remove member")}
                        onClick={() =>
                          update((c) => ({
                            ...c,
                            members: c.members.filter((x) => x !== member),
                          }))
                        }
                      >
                        <Trash2 />
                      </IconBtn>
                    )}
                  </Row>
                ))}
              {s.role === "owner" &&
                s.members.map((member) => (
                  <fieldset key={member}>
                    <legend>{member}</legend>
                    {["view", "add", "edit", "remove", "invite", "members"].map(
                      (key, i) => (
                        <label className="check" key={key}>
                          <input
                            type="checkbox"
                            checked={
                              (n.prefs[id + member + key] ??
                                (["view", "add"].includes(key) ? "1" : "0")) ===
                              "1"
                            }
                            onChange={(e) =>
                              n.pref(
                                id + member + key,
                                e.target.checked ? "1" : "0",
                              )
                            }
                          />
                          {n.t(
                            [
                              ["عرض", "View"],
                              ["إضافة أعمال", "Add titles"],
                              ["تعديل", "Edit"],
                              ["إزالة أعمال", "Remove titles"],
                              ["إدارة الدعوات", "Manage invites"],
                              ["إدارة الأعضاء", "Manage members"],
                            ][i] as [string, string],
                          )}
                        </label>
                      ),
                    )}
                  </fieldset>
                ))}
              {s.invite && (
                <>
                  <label>
                    {n.tr("رمز الدعوة", "Invite code")}
                    <input readOnly value={s.id + "-" + s.token} />
                  </label>
                  <Btn
                    onClick={() =>
                      navigator.clipboard
                        .writeText(s.id + "-" + s.token)
                        .then(() => n.setToast(n.tr("تم النسخ", "Copied")))
                        .catch(() =>
                          n.setToast(
                            n.tr(
                              "حدد الرمز لنسخه",
                              "Select the code to copy it",
                            ),
                          ),
                        )
                    }
                  >
                    <Clipboard />
                    {n.tr("نسخ", "Copy")}
                  </Btn>
                  <Btn
                    onClick={() =>
                      update((c) => ({ ...c, token: c.token + 1 }))
                    }
                  >
                    {n.tr("تجديد الدعوة", "Rotate invite")}
                  </Btn>
                </>
              )}
            </>
          )}
          {panel === "delete" && (
            <>
              <p>
                {s.role === "owner"
                  ? n.tr("هل تريد حذف المجموعة؟", "Delete this collection?")
                  : n.tr("هل تريد مغادرة المجموعة؟", "Leave this collection?")}
              </p>
              <Btn
                primary
                onClick={() => {
                  n.editLib((l) => ({
                    ...l,
                    shelves: l.shelves.filter((x) => x.id !== id),
                  }));
                  n.setLibTab("collections");
                  n.go("library", true);
                }}
              >
                {n.tr("تأكيد", "Confirm")}
              </Btn>
            </>
          )}
        </Modal>
      )}
      {error && (
        <Modal
          title={n.tr("تعدّلت المجموعة", "Collection has changed")}
          onClose={() => setError(false)}
        >
          <Btn
            onClick={() => {
              n.setScenario("ready");
              setError(false);
            }}
          >
            {n.tr("تحديث ثم إعادة المحاولة", "Reload and retry")}
          </Btn>
        </Modal>
      )}
    </div>
  );
}
export function Downloads() {
  const n = useNova();
  const [remove, setRemove] = useState("");
  const names = {
    active: n.tr("قيد التنزيل", "Downloading"),
    ready: n.tr("جاهز", "Ready"),
    failed: n.tr("فشل التنزيل", "Failed"),
    cancelled: n.tr("ملغى", "Cancelled"),
    missing: n.tr("الملف مفقود", "File missing"),
  };
  return (
    <div className="page">
      <Heading back title={n.tr("التنزيلات", "Downloads")} />
      {!n.downloads.length && (
        <Empty title={n.tr("لا توجد تنزيلات", "No downloads")} />
      )}
      {n.downloads.map((d) => {
        const m = mediaById(d.media)!;
        const state =
          n.scenario === "missing" && d.status === "ready"
            ? "missing"
            : d.status;
        return (
          <div key={d.id} className="download-entry">
            <Art media={m} />
            <div>
              <h3>{n.t(m.name)}</h3>
              <small>
                {names[state]} · {d.progress}%
              </small>
              {state === "active" && <progress value={d.progress} max="100" />}
              <div className="actions">
                {state === "ready" ? (
                  <Btn onClick={() => n.go("player/" + d.media + "/" + d.ep)}>
                    {n.tr("تشغيل", "Play")}
                  </Btn>
                ) : (
                  <Btn
                    onClick={() => {
                      if (state === "missing") n.setScenario("ready");
                      n.setDownloads((all) =>
                        all.map((x) =>
                          x.id !== d.id
                            ? x
                            : {
                                ...x,
                                status:
                                  state === "active" ? "cancelled" : "active",
                                progress: state === "active" ? d.progress : 0,
                              },
                        ),
                      );
                    }}
                  >
                    {state === "active"
                      ? n.tr("إلغاء", "Cancel")
                      : n.tr("إعادة التنزيل", "Retry")}
                  </Btn>
                )}
                <IconBtn
                  label={n.tr("حذف", "Remove")}
                  onClick={() => setRemove(d.id)}
                >
                  <Trash2 />
                </IconBtn>
              </div>
            </div>
          </div>
        );
      })}
      {remove && (
        <Modal
          title={n.tr("حذف التنزيل؟", "Remove download?")}
          onClose={() => setRemove("")}
        >
          <Btn
            primary
            onClick={() => {
              n.setDownloads((all) => all.filter((x) => x.id !== remove));
              setRemove("");
            }}
          >
            {n.tr("حذف", "Remove")}
          </Btn>
        </Modal>
      )}
    </div>
  );
}
export function MagnetFiles() {
  const n = useNova();
  return (
    <div className="page">
      <Heading back title={n.tr("ملفات التورنت", "Torrent files")} />
      <Row
        title="The Sand Atlas.mp4"
        note="1080p · 2.1 GB"
        icon={<ArrowDownToLine />}
        onClick={() => n.go("player/sand/1")}
      />
    </div>
  );
}
