# المشاهدة الجماعية: NuvioMobile وHarbor

تاريخ الفحص: **11 نوفمبر 2026**. المطلوب: تفسير الميزة في النسختين المحليتين باستخدام REA، وحفظ أدلة يمكن الرجوع إليها. لم تتغير شيفرة NOVA أو المشروعين المرجعيين، ولم تُنشأ غرفة على خدمة حية.

## النتيجة

المشروعان ينسقان تشغيل فيديو مستقل على جهاز كل مشارك؛ الخادم ينقل الحالة والأوامر والحضور. لا يوجد في مسار Party المفحوص بث شاشة أو نقل الفيديو من جهاز المضيف إلى الضيوف.

**Nuvio أوسع في منطق المزامنة والتعامل مع buffering، وHarbor أوضح في تنفيذ الخادم لأن كود relay موجود محليًا.** Nuvio يتيح أيضًا مشاركة رابط الفيديو وترويساته اختياريًا؛ Harbor يرسل وصف المصدر وtorrent hash في العقد المعتاد. لا يتوافق بروتوكولاهما مباشرة.

التفاصيل الكاملة لـNuvio في [NUVIO_PARTY.md](C:/Users/hosea/projects/app/Nova/docs/watch-party/NUVIO_PARTY.md). ما يلي يجمع المقارنة ونتائج Harbor والتوصيات المستخلصة.

## طريقة الفحص وحدود الثقة

| نوع الدليل | ما نُفذ | ما يثبته |
|---|---|---|
| REA على Harbor | `analyze_javascript_application` على 15 ملفًا محددًا؛ 14 ملف JS/TS/TSX مقروءًا دون فشل parsing، وpackage.json | هوية الملفات وتحليل syntax وعلاقات ساكنة؛ لا يثبت تشغيل التطبيق |
| تتبع REA | فحص حقائق worker/client وتتبع module الخاص بالـworker | علاقات مرشحة موثقة؛ ليست call graph كاملة أو تنفيذًا فعليًا |
| REA على Nuvio | `open_binary` ثم `inspect_artifact` لأرشيف مصادر محدد، 25 ملفًا وmanifest | هوية أرشيف المصدر ومحتوياته؛ **ليس فك APK أو تحليل دلالات Kotlin** |
| قراءة المصادر | ملفات Party وربطها بالمشغلات وواجهات الانضمام والخادم | تفسير التنفيذ الموجود في هذه النسخ المحلية |
| إعادة تشغيل محلية | 14 تحققًا على Room الحقيقي وTogetherClient الحقيقي بعد إزالة أنواع TypeScript | السلوك ضمن mocks محلية للتخزين وWebSocket وCloudflare؛ ليست جلسة بين جهازين |

REA متاح في الجلسة، لذلك لم يحتج تثبيتًا أو تغيير إعدادات. `capture_process_scenario` أعاد `capability_unavailable` لأن التقاط PTY غير مدعوم على Windows. أُجريت التجارب مباشرة بواسطة Node **v24.16.0**، ولم تُنسب إلى التقاط REA.

مدخل Harbor كان شجرة المصدر المحلية، رغم تسمية REA العامة `shipped-artifact` في سجل Evidence؛ لم تُفحص حزمة منشورة. التحليل الكلي **partial**: تُرك 5289 ملفًا خارج اختيار مصادر REA، والعلاقات الديناميكية والملفات غير المختارة تبقى مجهولة. سجل REA عدد 65153 semantic unknown؛ ليست هذه قائمة أخطاء في الميزة. تتبع literal باسم `claim-host` لم يعثر على seed دلالي وتقريره partial؛ لا يُستخدم دليلًا على غياب هذا الأمر، الموجود صراحة في المصدر والتجربة المحلية.

النسختان بلا `.git` محلية، لذلك commit غير معروف. Harbor يعلن **0.9.127** في package.json وMIT في LICENSE؛ Nuvio يعلن **0.6.2 / build 145** وملف GPLv3. هذه هوية ملفات النسختين، وليست تحققًا من أحدث إصدار منشور أو إرشادًا قانونيًا.

## المقارنة

| المحور | NuvioMobile | Harbor |
|---|---|---|
| النقل | Supabase RPC + Realtime private channel | WebSocket إلى Cloudflare Worker / Durable Object |
| حساب مطلوب | العميل يشترط مستخدمًا authenticated غير anonymous | عقد relay لا يطلب حسابًا أو JWT؛ الاسم وclientId من العميل |
| إنشاء الغرفة | RPC يولد الرمز | العميل يولد الرمز؛ المسار يختار Durable Object |
| الرمز المعتاد | 6 أحرف من أبجدية تستبعد الرموز الملتبسة | 6 أحرف من الأبجدية نفسها؛ مسار الخادم يقبل 4–8 أحرف/أرقام |
| الدعوة | HTTPS على nuvio.tv أو nuvio scheme | رابط يتضمن harbor-relay وharbor-room |
| الانضمام | preview ثم تأكيد؛ فتح اختيار المصدر | رابط الغرفة يضبط relay وينضم؛ دعوة media تفتح picker بعد 4 ثوان أو بضغط المستخدم |
| تحكم المشاركين | وضع جماعي أو host-only، مع حراسة المشغل | الضيف يرسل cmd إلى المضيف؛ المضيف ينفذ وينشر الحالة |
| ترتيب الحالة | seq ثم member_id | updatedAt للحالة؛ seq لكل مرسل seek في مسار المضيف |
| الساعة | monotonic مثبتة بعينة server وأفضل RTT | Date.now مع offset من pong وتنعيم 70/30 |
| تصحيح الفرق أثناء التشغيل | rate ±5% بعد 250ms؛ seek بعد 1500ms | seek عند فرق يتجاوز 600ms، مع حراسة catch-up/buffer |
| buffering | coordinator يوقف المجموعة مؤقتًا؛ حد انتظار 15 ثانية | حراسة محلية للتصحيح، دون بروتوكول انتظار جماعي مماثل في المسار المفحوص |
| التأخر الشخصي | behind يسمح بالتوقف/الرجوع دون إيقاف الجميع | لا حالة behind مقابلة في العقد المفحوص |
| اختيار المصدر | hash/fileIdx ثم filename ثم addon+label | درجات تطابق hash/fileIdx/resolution/size/title |
| مشاركة رابط الفيديو | اختياريًا URL + request/response headers عبر Realtime | SourceDescriptor المعتاد دون URL أو headers |
| الدردشة | RPC history + Realtime، optimistic/retry/dedup | broadcast حي؛ آخر 200 رسالة في ذاكرة الواجهة |
| انتقال المضيف | يتلقى host من snapshots/events؛ backend غير موجود | الخادم يختار أقدم مشارك متبقٍ؛ ويمكن لأي عضو claim-host |
| الاستمرار | غرفة العميل في الذاكرة؛ backend غير متاح للفحص | syncState وhost وstarted في Durable Object storage |
| حدود الخدمة | max_members قادم من الخادم؛ default model=3 لا يثبت حد الخدمة | لا سقف أعضاء أو password في Room المفحوص |
| التحقق الفعلي | مصدر فقط؛ 46 تعريف اختبار لم تُشغّل | مصدر + REA static + 14 تجربة محلية |

أرقام التصحيح تصف مسارات محددة في الكود؛ لا تمثل دقة مقاسة أو مقارنة أداء على أجهزة. في Nuvio تطبيق command جديد قد يستخدم عتبة 500ms؛ عتبة 1500ms تخص التصحيح الدوري.

## Harbor: رحلة الغرفة والبروتوكول

1. `TogetherProvider` يحتفظ بـclientId عشوائي في localStorage، مع الاسم وهوية العرض. `createSession` يولد الرمز باستخدام `crypto.getRandomValues`، و`joinSession` ينظفه. الإعداد الافتراضي `togetherRelayUrl` فارغ، فلا تعني معرفة عنوان relay العام أنه مُفعّل افتراضيًا. [H1،H2،H11]
2. `TogetherClient` يفتح `${relay}/r/${room}` ثم يرسل `hello`. خادم Worker يحول اسم الغرفة إلى Durable Object ويقبل WebSocket. أول peer يصبح المضيف. الـroom في payload ليس حاجز تفويض؛ المسار يحدد الغرفة، والـsocket يحدد peer داخلها. [H2،H3]
3. الخادم يعيد `joined` وفيه participants وsyncState وhostClientId وstarted وsrvAt وrelayVersion. عميل Harbor يتطلب relay version 11؛ `WT_PROTO=2` علامة بروتوكول دعوة/مصدر مستقلة عن worker version. [H1،H2،H3،H11]
4. رابط الدعوة يحمل relay والغرفة. القراءة التلقائية تضبط relay في الإعدادات ثم تنضم. هذه بيانات اتصال واردة من الرابط، وليست تحققًا من موثوقية relay. دعوة media داخل الغرفة تُعرض كتذكير مع عد تنازلي 4 ثوان، ثم تفتح picker؛ `guestPick=true` يمنع autoPlay. [H7]
5. المشغل ينشر readiness عندما تتوفر أبعاد الفيديو ومدة موجبة؛ ينتظر البداية. المضيف يستطيع البدء دون اكتمال ready للجميع. تظهر الحالة stale بعد 20 ثانية، وللضيف مسار خروج من انتظار البداية بعد 45 ثانية. هذه حراسة واجهة، لا شرط إجماع على الخادم. [H4،H5]
6. المضيف ينشر snapshot كل ثانية بعد البداية عند حالة playing/paused وموضع موجب. الضيف يرسل play/pause/seek إلى المضيف؛ الخادم يوجهها له فقط. seek يُجمع كل 250ms ثم يُطبّق على المضيف بعد debounce قدره 120ms. الـseq يمنع seek قديمًا من نفس مرسل الأمر. [H2،H3،H4،H6]
7. عند مغادرة المضيف يختار Room أقدم peer متبقٍ. `claim-host` يستطيع كذلك تغيير المضيف؛ `fresh=true` يعيد started وready إلى false. [H3]

العقد الأساسي:

```text
SyncState = mediaId, mediaTitle, episode, posterUrl,
            positionSeconds, playing, speed?, source?, guestPick?,
            updatedAt, updatedBy, hostClientId
RoomCommand = play | pause | seek(positionSeconds, seq?, at?)
```

رسائل العميل: hello/profile/leave/state/cmd/chat/invite/ready/host-leaving/claim-host/start/summon/cursor/draw/presence/ping. الخادم يرد بنظائرها وبانضمام/مغادرة/استعداد الأعضاء وhost وstarted وpong وerror. الرسم والمؤشر وsummon وموضع تصفح العضو ميزات اجتماعية إضافية، مستقلة عن نقل الفيديو. [H1،H3]

## Harbor: حساب الموضع وتصحيح الانحراف

`pong` يحمل ساعة الخادم. العميل يحسب `offset = srvAt - (pingSentAt + RTT/2)`، ويرفض RTT خارج 0–10 ثوان، ثم ينعّم العينات اللاحقة بـ70% قديم و30% جديد. وصول state يحول `srvAt` إلى updatedAt في نطاق ساعة الجهاز. قبل أول pong يستخدم تقديرًا من وقت الاستقبال. [H2:592]

إذا كان التشغيل مستمرًا:

```text
age = clamp((localNow - localizedUpdatedAt) / 1000, 0, 30)
target = positionSeconds + age + 0.4 seconds
```

عند pause يكون target هو الموضع المسجل. يُحد target بمدة الفيديو ناقص 0.25 ثانية. speed يُطبّق على المشغل، لكن معادلة target في هذا المسار **لا تضرب age في speed**؛ ينبغي فحص التشغيل بسرعات مختلفة عند أي إعادة تنفيذ. [H4]

يُرفض عنوان/حلقة مختلفة، وتُتجاهل الحالة الأقدم وفق updatedAt والحالة الصادرة من النفس. فرق أكبر من0.6 ثانية أو تغير play/pause يؤدي إلى seek. بعد التصحيح توجد حراسة catch-up تمنع تكرار seek الصغير أثناء نقص buffer؛ jump يتجاوز10 ثوان يتخطى تلك الحراسة. ينفصل مسار cast عن المشغل المحلي، ونشر cast كل3 ثوان. لم يُختبر cast فعليًا. [H4،H5]

## Harbor: المصادر والدردشة والاستمرار

SourceDescriptor يصف title/resolution/sizeBytes/infoHash/fileIdx/durationSec. بناء الوصف والـsanitizer لا يحتفظان URL أو request headers داخله. يمكن إعادة بناء خيار torrent من hash إذا كانت وسيلة تشغيله متاحة للضيف؛ ليس كل HTTP stream قابلاً للنقل بهذه الطريقة. [H8]

التقييم: hash مطابق +1000، fileIdx مطابق عند توفره +50، resolution +200، تقارب الحجم حتى+150، تشابه كلمات العنوان حتى+120، release group +40. badge «same» يبدأ1000 و«close» يبدأ300. **hash نفسه مع fileIdx مختلف قد يبقى موسومًا same** لأن threshold يعتمد مجموع النقاط، فلا يكفي badge لإثبات ملف/حلقة متطابقة. [H8]

الدردشة trim وحد500 حرف على الخادم، وتصل لكل المشاركين بما فيهم المرسل. الواجهة تحتفظ بآخر200 رسالة. لا جدول history أو replay chat للمتأخر في Room المفحوص. بالمقابل، syncState وhostClientId وstarted محفوظة صراحة في Durable Object storage وتُستعاد عند إعادة إنشاء الكائن؛ avatar غير محفوظ في attachment ويُعاد عبر profile. [H3،H9]

`ROOM_IDLE_MS=6h` يُفحص داخل onClose فقط، بعد خلو peers ومضي المدة منذ آخر رسالة. لا يوجد alarm أو timer يغلق غرفة نشطة بعد6 ساعات، وشرط cleanup لا يمسح started. لذلك لا يصح تحويل عبارة واجهة «rooms drop after 6 hours» إلى TTL فعلي ثابت. [H3:546]

## نتائج تستحق المعالجة عند إعادة التنفيذ

| الملاحظة | الدليل | النتيجة العملية |
|---|---|---|
| تعطل reconnect بعد successful join | joined يضبط attemptResolved=true؛ onclose يستدعي failAttempt الذي يعود فورًا عند true | في التجربة بقي snapshot=joined ولم يُجدول retry بعد الانقطاع؛ يلزم إصلاح دورة الاتصال في تنفيذ مستقل |
| أي عضو يستطيع claim-host | handleClaimHost يتحقق من وجود peer فقط | host-only state writes لا تعني أن المضيف محمي من الاستبدال |
| clientId غير موثق | hello يقبل ID من العميل ويغلق socket سابقًا عند تكراره | معرفة room وclientId كافية لتبديل socket في هذا النموذج؛ لا توجد هوية حساب موثقة في العقد |
| invite وsummon متاحان لأي peer | handleInvite وhandleSummon لا يشترطان المضيف | دعوة عنوان جديد ليست عملية مضيف حصرية على الخادم |
| لا سياسة rate موحدة للغرفة | checkRate مستخدم في /proxy؛ host state يتجاوز فرع throttle المحلي في handleState | حد60/دقيقة الموجود يخص proxy، ولا يثبت حماية chat/cmd/state |
| فحص الوقت والسرعة محدود | host updatedAt رقمي دون ترتيب إلزامي؛ speed لا يتحقق منه handleState | لا يُنسخ هذا باعتباره بروتوكولًا محصنًا أمام عميل معدل |
| سلامة المصدر | descriptor مبسط والمطابقة بالدرجة | يلزم تحقق media/episode ونسخة الفيديو والمدة قبل المزامنة |
| Nuvio backend غائب | طلبات RPC موجودة دون SQL وسياسات Realtime | private=true وحراسة host في العميل لا يثبتان تفويض المرسل على الخادم |
| Nuvio URL sharing | payload يتضمن الرابط والترويسات | يحتاج سياسة إفصاح صريحة، والتحقق من البيانات والعناوين؛ الأفضل وصف المصدر افتراضيًا |

الملاحظات أعلاه تخص الكود المحلي. ليست إثباتًا لاستغلال خدمة منشورة، ولم يُجرَ أي اختبار هجومي على relay أو Supabase.

## ما أُعيد تشغيله محليًا

[البرنامج](C:/Users/hosea/projects/app/Nova/.codex/watch-party-harbor-probe.mjs) يستورد Room الحقيقي مباشرة، ويحوّل TogetherClient الحقيقي بأداة Node لإزالة أنواع TypeScript. التخزين وsockets والمؤقتات بدائل داخل الذاكرة، وfetch معطل. [نتائج 14 تحققًا](C:/Users/hosea/projects/app/Nova/.codex/watch-party-harbor-probe-results.json):

- أول عضو يصبح المضيف، والضيف لا يستطيع start أو كتابة state أثناء وجود مضيف.
- كتابة المضيف تُحفظ، وURL/headers تُحذف من source descriptor، وأمر الضيف يصل للمضيف فقط.
- أي عضو منضم يستطيع claim-host؛ start لا يشترط readiness، وغير المضيف يستطيع بث invite.
- chat يُقص إلى500 حرف ويصل للمرسل؛ تكرار clientId يغلق socket السابق؛ مغادرة المضيف تنقل الدور.
- إعادة إنشاء Room تستعيد syncState وstarted؛ لا alarm لانتهاء غرفة نشطة بعد6 ساعات.
- إغلاق socket بعد joined ناجح يبقي الحالة joined دون retry مجدول.

نجاح هذه التحققات يعني أن السلوك الموصوف قابل لإعادة الإنتاج في البيئة المحلية المحدودة، بما فيه السلوك غير المرغوب. لا يعني نجاح قبول الميزة على أجهزة أو Cloudflare.

## اقتراح مستقل لـNOVA، دون تنفيذ

الاختيار المبدئي هو فصل عضوية الغرفة وتفويضها على الخادم عن مزامنة المشغل. يمكن الاستفادة من نموذج Nuvio للساعة وseq وbehind وbuffering، ومن فصل Harbor بين snapshot وأمر الضيف ووصف المصدر، مع كتابة تنفيذ مستقل يناسب PlaybackSession في NOVA.

الحد الأدنى المقترح: عضوية مرتبطة بالحساب ومتحقق منها server-side؛ epoch للمضيف وrevision للأوامر؛ transfer-host محكوم؛ media key للحلقة والنسخة؛ snapshot عند rejoin؛ heartbeat وTTL وrate limits معلنة؛ adapter لأوامر المشغل exact بدل توصيله بقيم UI المؤجلة؛ source generations وإلغاء الأوامر القديمة عند تبديل المصدر أو إغلاق المسار. مشاركة الرابط والترويسات ليست مطلوبة لتحقيق المشاهدة الجماعية.

قبل أي اعتماد: اختبار جهازين بتأخر شبكة وانقطاع وإعادة انضمام، تبديل مضيف، seek متزامن، buffering عضو واحد، اختلاف نسخة/مدة الفيديو، المصدر المنتهي، سرعات غير1×، الخلفية والاستئناف وPiP، وتبديل Media3/libmpv وإغلاق مسار Core. هذه توصيات بحثية، وليست بدء مرحلة تنفيذ أو تغييرًا في NOVA.

## سجل أدلة REA

الحزمة الكاملة: [watch-party-rea-evidence.json.gz](C:/Users/hosea/projects/app/Nova/.codex/watch-party-rea-evidence.json.gz). تضم8 سجلات Evidence. ضُغط JSON مع تحقق SHA-256 بعد فك الضغط؛ البصمة غير المضغوطة `24f58827397975733605903a5ce096413187454710fbb6ef45f9150ebb420d48`.

| المرجع | Evidence ID |
|---|---|
| Harbor application parent | `ev_1493ee997dcfacf80427214747c3e51f2009dd29a8b473112f605797f74cf356` |
| Harbor summary | `ev_4b7c1124ba17ebc123408e9e087a384c79823761807b1dc836d6386807478f2f` |
| worker/client facts | `ev_68ac962f3b04c9b6762222cc02bcbfc57dab8530a2a0ad89f9af39808bfcf2b0` |
| worker module trace | `ev_f6c9bf5edc672504863b512b8b1a12b2e795e67452e64a5de8c32d06a4b6c6d1` |
| semantic trace غير الحاسم | `ev_be48236196e00734a3e394b875f2eb15fd8c552e713ed72f667fc6d453e3fd41` |
| Nuvio source ZIP inventory | `ev_77d2d785da2a0b65f6c955ec5402ff92dd679d89e70f7970844238a85e5352e9` |
| Nuvio source ZIP inspection | `ev_6985da42615dd0318106d1eb2efcdc1c630c7240acc89bd14b5c20fc0b8141e1` |
| Nuvio source ZIP summary | `ev_f8630ab7d9ffece2c4bfafec7ba8b8dc77687028a8e476699847c1313403c476` |

Harbor artifact-root SHA-256: `6b29ce445588057761a282757cbc049ab29d673f161d804145a6eac9582dd9a1`. worker SHA-256: `1afad70b725fc0d5bb9544940c4fcb18fb060f33ac9276d059e2f4affe71297a`. client SHA-256: `b3731745ee0a4cbcfb7a28608130a4a2ab4443775c9abe8fb566186beeb915b0`.

Nuvio [source snapshot ZIP](C:/Users/hosea/projects/app/Nova/.codex/watch-party-nuvio-source-snapshot.zip): SHA-256 `b78e1f874392c6e9dbd764adebf6f65a4883eb7dc15caaeb5ec382ae6bcc3e64`. [Manifest](C:/Users/hosea/projects/app/Nova/.codex/watch-party-nuvio-source-manifest.json). [سبب عدم توفر REA process capture](C:/Users/hosea/projects/app/Nova/.codex/watch-party-rea-process-capture-limitation.json). أُغلقت جلسة REA بعد تصدير الأدلة.

## خريطة مصادر Harbor

| الرمز | المصدر |
|---|---|
| H1 | [protocol.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/lib/together/protocol.ts:24) — schema والرسائل والرمز |
| H2 | [client.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/lib/together/client.ts:19) — النقل والساعة وإعادة الاتصال |
| H3 | [worker.js](C:/Users/hosea/projects/app/player-refereences/harbor/src-tauri/relay/worker.js:140) — Room والتفويض والتخزين |
| H4 | [use-room-sync.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/views/player/hooks/use-room-sync.ts:99) — النشر والتطبيق والتصحيح |
| H5 | [player-utils.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/views/player/player-utils.ts:6)، [use-lobby-gate.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/views/player/hooks/use-lobby-gate.ts:44) — الثوابت وانتظار البداية |
| H6 | [seek-coalesce.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/lib/together/seek-coalesce.ts:3)، [use-playback-controls.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/views/player/hooks/use-playback-controls.ts:178) — أوامر الضيف |
| H7 | [invite.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/lib/together/invite.ts:15)، [provider.tsx](C:/Users/hosea/projects/app/player-refereences/harbor/src/lib/together/provider.tsx:254)، [together-invite-toast.tsx](C:/Users/hosea/projects/app/player-refereences/harbor/src/components/together-invite-toast.tsx:8) — الدعوات والانضمام |
| H8 | [source-descriptor.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/lib/together/source-descriptor.ts:17)، [source-match.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/lib/together/source-match.ts:16)، [host-stream.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/lib/together/host-stream.ts:14) — وصف المصدر ومطابقته |
| H9 | [provider-events.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/lib/together/provider-events.ts:17) — أحداث الواجهة وحد chat |
| H10 | [package.json](C:/Users/hosea/projects/app/player-refereences/harbor/package.json:1)، [LICENSE](C:/Users/hosea/projects/app/player-refereences/harbor/LICENSE:1) — هوية النسخة |
| H11 | [defaults.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/lib/settings/defaults.ts:202)، [relay-version.ts](C:/Users/hosea/projects/app/player-refereences/harbor/src/lib/together/relay-version.ts:1) — الإعداد الافتراضي والتوافق |

## حالة الأسئلة

| السؤال | الحالة |
|---|---|
| إنشاء الغرفة والانضمام والدعوات وتجربة العضو | مجاب من المصدر |
| النقل والعقود والساعة والمزامنة ودمج المشغل | مجاب من المصدر، مع حدود REA المذكورة |
| الدردشة والمصادر والعضوية والاستمرار | مجاب من المصدر |
| صلاحيات Harbor وبعض عيوب دورة الاتصال | مصدر + إعادة تشغيل محلية |
| صلاحيات Nuvio/RLS/TTL/quotas الحقيقية | غير محسوم؛ backend غير موجود |
| تطابق المصدر مع حزمة منشورة | غير متحقق لكليهما |
| أداء فعلي، جودة التزامن، Android/iOS/desktop/cast | غير مقاس وغير مختبر بين أجهزة |

اكتمل نطاق التحقيق المحلي المتاح؛ الأسئلة التي تحتاج backend أو حزمة مبنية أو أجهزة تبقى مفتوحة كما في الجدول.
