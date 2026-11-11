export type Pair = readonly [string, string];
export type Media = {
  id: string;
  name: Pair;
  genre: Pair;
  story: Pair;
  year: number;
  mins: number;
  type: "film" | "series" | "anime";
  age: string;
  score: number;
  family?: boolean;
};
export const films: Media[] = [
  {
    id: "sand",
    name: ["أثر الرمل", "The Sand Atlas"],
    genre: ["مغامرة", "Adventure"],
    year: 2026,
    mins: 108,
    type: "film",
    age: "12+",
    score: 8.6,
    story: [
      "تعود رسّامة خرائط إلى وادٍ ناءٍ في العلا، فتقودها علامة محفورة في الصخر إلى آخر رحلة قام بها والدها.",
      "A cartographer returns to a remote valley in AlUla. A mark carved into the sandstone leads her back to her father’s final expedition.",
    ],
  },
  {
    id: "tide",
    name: ["آخر ضوء", "Last Light"],
    genre: ["غموض", "Mystery"],
    year: 2025,
    mins: 48,
    type: "series",
    age: "15+",
    score: 8.4,
    story: [
      "تصل رسالة إلى منارة مهجورة مع كل مدّ. يبدأ حارسها الجديد بتتبّع الرسائل عبر الساحل.",
      "A letter finds its way to an abandoned lighthouse with every tide. Its new keeper follows the trail along the coast.",
    ],
  },
  {
    id: "night",
    name: ["بعد منتصف الليل", "Past Midnight"],
    genre: ["جريمة", "Crime"],
    year: 2024,
    mins: 112,
    type: "film",
    age: "16+",
    score: 7.9,
    story: [
      "في ليلة ممطرة، يربط مسجّل صوت قديم بين موسيقية وسائق أجرة في شوارع طوكيو.",
      "A misplaced tape recorder brings a musician and a cab driver together on a rainy night in Tokyo.",
    ],
  },
  {
    id: "wind",
    name: ["على جناح الريح", "Riding the Wind"],
    genre: ["أنمي", "Anime"],
    year: 2026,
    mins: 24,
    type: "anime",
    age: "7+",
    score: 8.8,
    family: true,
    story: [
      "تكتشف فتاة من قرية جبلية أن الريح تحمل رسائل من الجانب الآخر للغابة.",
      "In a mountain village, a girl discovers that the wind carries messages from the other side of the forest.",
    ],
  },
  {
    id: "fox",
    name: ["درب الثعلب", "Little Fox"],
    genre: ["عائلي", "Family"],
    year: 2025,
    mins: 83,
    type: "film",
    age: "G",
    score: 8.1,
    family: true,
    story: [
      "يخرج ثعلب صغير من جحره قبل الربيع، ويتعلّم طريق العودة بمساعدة أصدقاء الغابة.",
      "A little fox leaves its den before spring and learns the way home with help from its woodland friends.",
    ],
  },
  {
    id: "orbit",
    name: ["المدار الأخير", "Last Orbit"],
    genre: ["خيال علمي", "Science fiction"],
    year: 2026,
    mins: 51,
    type: "series",
    age: "12+",
    score: 8.3,
    story: [
      "من قمر بعيد، تسمع مهندسة فضاء إشارة من محطة توقفت عن الإرسال قبل عشرين عامًا.",
      "On a distant moon, a flight engineer hears a signal from a station that fell silent twenty years ago.",
    ],
  },
];
export const mediaById = (id: string) => films.find((f) => f.id === id);
export const dests = {
  home: ["الرئيسية", "Home"],
  discover: ["اكتشف", "Discover"],
  anime: ["الأنمي", "Anime"],
  library: ["مكتبتي", "My Library"],
  kids: ["الأطفال", "Kids"],
} satisfies Record<string, Pair>;
export type Dest = keyof typeof dests;
export const settingNames = {
  account: ["الحساب", "Account"],
  playback: ["التشغيل", "Playback"],
  subtitles: ["الترجمة", "Subtitles"],
  downloads: ["التنزيلات والتخزين", "Downloads & storage"],
  appearance: ["المظهر", "Appearance"],
  display: ["عرض المحتوى", "Content display"],
  catalogs: ["إدارة الكتالوجات", "Catalog management"],
  language: ["اللغة", "Language"],
  notifications: ["الإشعارات", "Notifications"],
  privacy: ["الخصوصية والبيانات", "Privacy & data"],
  addons: ["الإضافات", "Add-ons"],
  services: ["الخدمات المرتبطة", "Linked services"],
  kids: ["إعدادات الأطفال", "Kids settings"],
  stats: ["الإحصاءات", "Statistics"],
  about: ["حول NOVA", "About NOVA"],
} satisfies Record<string, Pair>;
export const providers = [
  "Trakt",
  "Simkl",
  "AniList",
  "MyAnimeList",
  "MDBList",
  "Letterboxd",
  "TMDB",
  "Debrid",
  "AniSkip",
  "IntroDB",
  "TheIntroDB",
];
export type Shelf = {
  id: string;
  name: string;
  description?: string;
  notes?: Record<string, string>;
  shared: boolean;
  items: string[];
  role: "owner" | "member";
  edit: boolean;
  invite: boolean;
  token: number;
  members: string[];
};
export type Profile = { id: string; name: string; pin: string; color: number };
export type Download = {
  id: string;
  media: string;
  ep: number;
  progress: number;
  status: "active" | "ready" | "failed" | "cancelled" | "missing";
};
export type Progress = { ep: number; pct: number };
export type Library = {
  watched: Record<string, number[]>;
  tracking: Record<string, { status: string; count: number; score: number }>;
  saved: string[];
  progress: Record<string, Progress>;
  shelves: Shelf[];
};
export const emptyLibrary = (): Library => ({
  watched: {},
  tracking: {},
  saved: [],
  progress: {},
  shelves: [],
});
export const demoLibrary = (): Library => ({
  watched: { tide: [1, 2] },
  tracking: {},
  saved: ["sand", "fox"],
  progress: {
    tide: { ep: 3, pct: 43 },
    orbit: { ep: 1, pct: 64 },
    wind: { ep: 2, pct: 25 },
  },
  shelves: [
    {
      id: "weekend",
      name: "Weekend cinema",
      shared: true,
      items: ["sand", "night", "orbit"],
      role: "owner",
      edit: true,
      invite: true,
      token: 1,
      members: ["Mira"],
    },
    {
      id: "skies",
      name: "Open skies",
      shared: false,
      items: ["wind", "orbit"],
      role: "owner",
      edit: true,
      invite: true,
      token: 1,
      members: [],
    },
  ],
});
export const navRoot = (route: string) => route.split("/")[0];
export function kidSafe(route: string) {
  const [area, id] = route.split("/");
  if (area === "kids") return true;
  return (
    ["title", "sources", "player"].includes(area) && !!mediaById(id)?.family
  );
}
export function initProfiles(): Profile[] {
  return [
    { id: "noor", name: "نور", pin: "", color: 0 },
    { id: "mira", name: "Mira", pin: "2468", color: 1 },
  ];
}
export function sessionOptions() {
  const p = new URLSearchParams(location.search);
  return {
    en: p.get("lang") === "en",
    theme: p.get("theme") || "dark",
    platform: p.get("platform") || "android",
    scenario: p.get("scenario") || "ready",
    large: p.get("size") === "200",
    reduced: p.get("motion") === "off",
    solid: p.get("glass") === "off",
    phone: p.get("device") === "iphone",
  };
}
