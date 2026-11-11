import {
  ArrowRight,
  Check,
  Download,
  Lock,
  Plus,
  Puzzle,
  Settings,
  Users,
} from "lucide-react";
import { useState } from "react";
import { useNova } from "./session";
import { Btn, Heading, Modal, Row } from "./ui";
export function Onboarding() {
  const n = useNova();
  return (
    <div className="auth page narrow">
      <img className="brand-mark" src="/brand/icon_red.svg" alt="NOVA" />
      <h1>{n.tr("مرحبًا بك في نوفا", "Welcome to NOVA")}</h1>
      <label>
        {n.tr("لغة الواجهة", "Interface language")}
        <select
          value={n.en ? "en" : "ar"}
          onChange={(e) => n.setEn(e.target.value === "en")}
        >
          <option value="ar">العربية</option>
          <option value="en">English</option>
        </select>
      </label>
      <label>
        {n.tr("المظهر", "Appearance")}
        <select value={n.theme} onChange={(e) => n.setTheme(e.target.value)}>
          {["dark", "light", "system"].map((x, i) => (
            <option key={x} value={x}>
              {
                [
                  n.tr("داكن", "Dark"),
                  n.tr("فاتح", "Light"),
                  n.tr("النظام", "System"),
                ][i]
              }
            </option>
          ))}
        </select>
      </label>
      <Btn primary onClick={() => n.go("welcome")}>
        {n.tr("ابدأ", "Get started")}
      </Btn>
    </div>
  );
}
export function AccountMenu() {
  const n = useNova();
  return (
    <div className="page narrow">
      <Heading back title={n.tr("ملفي", "Profile")} />
      <div className="identity">
        <span className="avatar">{n.profile.name.slice(0, 1)}</span>
        <h2>{n.profile.name}</h2>
      </div>
      {[
        ["profiles", n.tr("تبديل الملف", "Switch profile"), <Users />],
        [
          "profiles/manage",
          n.tr("إدارة الملفات", "Manage profiles"),
          <Users />,
        ],
        ["settings/account", n.tr("الحساب", "Account"), <Lock />],
        ["settings", n.tr("الإعدادات", "Settings"), <Settings />],
        ["downloads", n.tr("التنزيلات", "Downloads"), <Download />],
        ["settings/addons", n.tr("الإضافات", "Add-ons"), <Puzzle />],
      ].map(([to, label, icon]) => (
        <Row
          key={String(to)}
          title={String(label)}
          icon={icon}
          onClick={() => n.go(String(to))}
        />
      ))}
    </div>
  );
}
export function Profiles({ mode, id }: { mode?: string; id?: string }) {
  const n = useNova();
  const current = n.profiles.find((p) => p.id === id);
  const [name, setName] = useState(current?.name || ""),
    [pin, setPin] = useState(current?.pin || ""),
    [color, setColor] = useState(current?.color || 0),
    [prompt, setPrompt] = useState(""),
    [answer, setAnswer] = useState(""),
    [err, setErr] = useState(""),
    [def, setDef] = useState(current?.id === n.defaultProfile);
  const edit = mode === "edit" || mode === "new";
  const label = edit
    ? n.tr("تحرير الملف", "Edit profile")
    : mode === "manage"
      ? n.tr("إدارة الملفات", "Manage profiles")
      : n.tr("من يشاهد؟", "Who’s watching?");
  function select(id: string) {
    const p = n.profiles.find((x) => x.id === id);
    if (!p) return;
    if (p.pin) {
      setPrompt(id);
      setAnswer("");
      setErr("");
    } else n.activate(id);
  }
  return (
    <div className="page narrow">
      <Heading back title={label} />
      {edit ? (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            if (!name.trim() || (pin && !/^\d{4}$/.test(pin))) return;
            if (!current && n.profiles.length >= 5) return;
            const entry = {
              id: current?.id || crypto.randomUUID(),
              name: name.trim(),
              pin,
              color,
            };
            n.setProfiles((all) =>
              current
                ? all.map((p) => (p.id === id ? entry : p))
                : [...all, entry],
            );
            if (def) n.setDefaultProfile(entry.id);
            else if (n.defaultProfile === entry.id) n.setDefaultProfile("");
            if (!n.profiles.length) n.activate(entry.id);
            else n.go("profiles/manage", true);
          }}
        >
          <label>
            {n.tr("الاسم", "Name")}
            <input
              required
              maxLength={32}
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </label>
          <label>
            {n.tr("رمز اختياري من ٤ أرقام", "Optional four-digit PIN")}
            <input
              inputMode="numeric"
              pattern="[0-9]{4}"
              maxLength={4}
              value={pin}
              onChange={(e) => setPin(e.target.value)}
            />
          </label>
          <label>
            {n.tr("لون الصورة", "Avatar color")}
            <select
              value={color}
              onChange={(e) => setColor(Number(e.target.value))}
            >
              {[
                n.tr("أحمر", "Red"),
                n.tr("أزرق", "Blue"),
                n.tr("ذهبي", "Gold"),
              ].map((x, i) => (
                <option key={x} value={i}>
                  {x}
                </option>
              ))}
            </select>
          </label>
          <label className="check">
            <input
              type="checkbox"
              checked={def}
              onChange={(e) => setDef(e.target.checked)}
            />
            {n.tr("ملف افتراضي", "Default profile")}
          </label>
          <button className="btn primary">{n.tr("حفظ", "Save")}</button>
          {current && n.profiles.length > 1 && current.id !== n.profileId && (
            <Btn onClick={() => setPrompt("delete")}>
              {n.tr("حذف الملف", "Delete profile")}
            </Btn>
          )}
        </form>
      ) : (
        <>
          {n.profiles.map((p) => (
            <Row
              key={p.id}
              icon={
                <span className={"avatar a" + p.color}>
                  {p.name.slice(0, 1)}
                </span>
              }
              title={p.name}
              note={
                p.id === n.defaultProfile
                  ? n.tr("الافتراضي", "Default")
                  : undefined
              }
              onClick={() =>
                mode === "manage" ? n.go("profiles/edit/" + p.id) : select(p.id)
              }
            >
              {p.pin && <Lock size={16} />}
            </Row>
          ))}
          <Btn
            disabled={n.profiles.length >= 5}
            onClick={() => n.go("profiles/new")}
          >
            <Plus />
            {n.tr("إضافة ملف", "Add profile")} ({n.profiles.length}/5)
          </Btn>
        </>
      )}
      {prompt && (
        <Modal
          title={
            prompt === "delete"
              ? n.tr("حذف الملف؟", "Delete this profile?")
              : n.tr("رمز الملف", "Profile PIN")
          }
          onClose={() => setPrompt("")}
        >
          {prompt === "delete" ? (
            <Btn
              primary
              onClick={() => {
                n.setProfiles((all) => all.filter((x) => x.id !== id));
                n.go("profiles/manage", true);
              }}
            >
              {n.tr("حذف", "Delete")}
            </Btn>
          ) : (
            <form
              onSubmit={(e) => {
                e.preventDefault();
                const p = n.profiles.find((x) => x.id === prompt);
                if (p?.pin === answer) {
                  setPrompt("");
                  n.activate(prompt);
                } else setErr(n.tr("رمز غير صحيح", "Incorrect PIN"));
              }}
            >
              <label>
                PIN
                <input
                  autoFocus
                  type="password"
                  inputMode="numeric"
                  value={answer}
                  maxLength={4}
                  onChange={(e) => setAnswer(e.target.value)}
                />
              </label>
              {err && <p role="alert">{err}</p>}
              <button className="btn primary">{n.tr("فتح", "Unlock")}</button>
            </form>
          )}
        </Modal>
      )}
    </div>
  );
}
const forms = {
  signin: ["تسجيل الدخول", "Sign in"],
  signup: ["إنشاء حساب", "Create account"],
  reset: ["استعادة كلمة المرور", "Reset password"],
  verify: ["تأكيد البريد", "Verify email"],
  username: ["اختيار اسم المستخدم", "Choose username"],
  password: ["كلمة مرور جديدة", "New password"],
  upgrade: ["ترقية حساب الضيف", "Upgrade guest account"],
} as const;
export function Auth({ mode }: { mode: string }) {
  const n = useNova(),
    [error, setError] = useState("");
  const form = mode as keyof typeof forms;
  const [draft, setDraft] = useState({ user: "", email: "", password: "" });
  const next = () => {
    if (n.scenario === "error" || n.scenario === "offline") {
      setError(
        n.tr(
          "تعذّر الاتصال. احتُفظ بالمدخلات.",
          "Connection failed. Your entries were kept.",
        ),
      );
      n.setScenario("ready");
      return;
    }
    if (mode === "reset") n.go("auth/password");
    else if (mode === "signup" || mode === "upgrade") n.go("auth/verify");
    else if (mode === "verify") n.go("auth/username");
    else if (mode === "password") n.go("auth/signin");
    else if (mode === "username" && !n.guest) n.newAccount(false);
    else {
      n.signIn();
    }
  };
  return (
    <div className="auth page narrow">
      <img className="brand-mark" src="/brand/icon_red.svg" alt="NOVA" />
      {mode === "welcome" ? (
        <>
          <h1>{n.tr("أهلًا بك في نوفا", "Welcome to NOVA")}</h1>
          <p>
            {n.tr(
              "اختر ملفك واجمع ما تحب مشاهدته.",
              "Choose a profile and keep the titles you love together.",
            )}
          </p>
          <Btn primary onClick={() => n.go("auth/signin")}>
            {n.tr("تسجيل الدخول", "Sign in")}
            <ArrowRight className="direction" />
          </Btn>
          <Btn onClick={() => n.go("auth/signup")}>
            {n.tr("إنشاء حساب", "Create account")}
          </Btn>
          <button
            className="text-btn"
            onClick={() => {
              n.newAccount(true);
            }}
          >
            {n.tr("المتابعة كضيف", "Continue as guest")}
          </button>
        </>
      ) : (
        <>
          <Heading back title={n.t(forms[form] || forms.signin)} />
          <p className="muted">
            {n.tr(
              "استخدم بيانات تجريبية لهذه المعاينة.",
              "Use sample details for this preview.",
            )}
          </p>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              next();
            }}
          >
            {["username", "signup", "upgrade"].includes(mode) && (
              <label>
                {n.tr("اسم المستخدم", "Username")}
                <input
                  required
                  value={draft.user}
                  onChange={(e) => setDraft({ ...draft, user: e.target.value })}
                />
              </label>
            )}
            {["signin", "signup", "upgrade", "reset"].includes(mode) && (
              <label>
                {n.tr("البريد الإلكتروني", "Email")}
                <input
                  type="email"
                  required
                  value={draft.email}
                  onChange={(e) =>
                    setDraft({ ...draft, email: e.target.value })
                  }
                />
              </label>
            )}
            {["signin", "signup", "upgrade", "password"].includes(mode) && (
              <label>
                {n.tr("كلمة المرور", "Password")}
                <input
                  type="password"
                  minLength={6}
                  required
                  autoComplete="off"
                  value={draft.password}
                  onChange={(e) =>
                    setDraft({ ...draft, password: e.target.value })
                  }
                />
              </label>
            )}
            {mode === "verify" && (
              <p>
                {n.tr(
                  "أكمل خطوة التحقق التجريبية للمتابعة.",
                  "Complete the simulated verification to continue.",
                )}
              </p>
            )}
            {error && <p role="alert">{error}</p>}
            <button className="btn primary">
              <Check />
              {n.tr("متابعة", "Continue")}
            </button>
          </form>
          {mode === "signin" && (
            <button className="text-btn" onClick={() => n.go("auth/reset")}>
              {n.tr("نسيت كلمة المرور؟", "Forgot password?")}
            </button>
          )}
        </>
      )}
    </div>
  );
}
export function KidsGate() {
  const n = useNova(),
    [pin, setPin] = useState(""),
    [error, setError] = useState(false);
  return (
    <Modal
      title={
        n.gate === "kids-setup"
          ? n.tr("إعداد رمز الأهل", "Set a parent PIN")
          : n.tr("الخروج من وضع الأطفال", "Leave Kids mode")
      }
      onClose={() => n.setGate("")}
    >
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (!n.unlock(pin)) setError(true);
        }}
      >
        <label>
          {n.tr("رمز ولي الأمر", "Parent PIN")}
          <input
            type="password"
            inputMode="numeric"
            autoFocus
            maxLength={4}
            value={pin}
            onChange={(e) => {
              setPin(e.target.value);
              setError(false);
            }}
          />
        </label>
        {error && <p role="alert">{n.tr("الرمز غير صحيح", "Incorrect PIN")}</p>}
        <button className="btn primary">
          {n.gate === "kids-setup"
            ? n.tr("حفظ", "Save")
            : n.tr("خروج", "Leave")}
        </button>
      </form>
    </Modal>
  );
}
