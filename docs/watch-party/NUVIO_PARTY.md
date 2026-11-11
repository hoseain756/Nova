# تحليل Party في NuvioMobile

تاريخ الفحص: 2026-11-11. النطاق: `C:\Users\hosea\projects\app\player-refereences\NuvioMobile`، قراءة فقط؛ لم يتغير التطبيق ولم يتم الاتصال بالخدمة أو تسجيل الدخول أو تشغيل غرفة.

## هوية الأدلة وحدود REA

- المشروع Kotlin Multiplatform/Compose. [ملف الإصدار](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/iosApp/Configuration/Version.xcconfig:1) يعلن `0.6.2` وbuild `145`، ويقرأه Gradle افتراضيًا. لا توجد `.git` في هذه النسخة، لذلك commit غير معروف.
- [LICENSE](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/LICENSE:1) يحتوي نص GNU GPL Version 3. هذه ملاحظة عن الملف الموجود، دون استنتاج قانوني أو نقل تنفيذ إلى NOVA.
- جرد `rg --files -uu` داخل المشروع لم يجد APK/AAB/IPA أو SQL أو AGENTS.md. جرد أولي للمجلد المرجعي كذلك لم يعثر على حزمة Nuvio. هذا بحث محلي محدود، ولا يثبت غياب artifact في بقية الجهاز.
- **هذا الجزء تحليل مصدر ثابت؛ لا توجد حزمة Nuvio مبنية مناسبة لفكها بـ REA.** لم تُستعمل وظيفة JavaScript على Kotlin. جُهز [ZIP للـ25 ملف مصدر المختارة وmanifest](C:/Users/hosea/projects/app/Nova/.codex/watch-party-nuvio-source-snapshot.zip) لكي يوثق REA هوية الأرشيف ومحتوياته فقط؛ هذا لا يحول تحليل Kotlin إلى decompilation. يضيف التقرير الرئيسي Evidence IDs الخاصة بفحص الأرشيف وHarbor.
- [manifest ببصمات SHA-256 لـ25 ملفًا](C:/Users/hosea/projects/app/Nova/.codex/watch-party-nuvio-source-manifest.json) يثبت ملفات المصدر الأساسية والاختبارات؛ ليس دليلًا على تطابقها مع التطبيق المنشور. ZIP به26 entry، حجمه99,749 bytes، وSHA256=`b78e1f874392c6e9dbd764adebf6f65a4883eb7dc15caaeb5ec382ae6bcc3e64`.
- لم تُشغّل اختبارات Gradle، ولم تُبنَ Android أو iOS، ولم يُتحقق من زمن المزامنة أو خدمة Supabase الحية أو أمان سياساتها.

## النتيجة الأساسية

الميزة تنسق مشغلات مستقلة. الحالة المشتركة هي هوية الفيلم/الحلقة، paused، position، rate وتوقيت خادم تقديري. كل جهاز يحل مصادره الخاصة مع إبراز المصدر المطابق؛ ويمكن للمضيف تشغيل خيار منفصل لمشاركة HTTP(S) URL وترويساته للأعضاء. لا يوجد في هذا المسار بث شاشة أو إعادة إرسال بايتات الفيديو بين الأجهزة، ولا صوت/فيديو مكالمات في ملفات Party المفحوصة.

طبقتان للاتصال: RPC لإدارة العضوية واللقطات الدائمة والدردشة، وSupabase Realtime خاص لإيصال الأوامر والحضور بسرعة. واجهة المستخدم والحراسة المحلية واضحة، لكن خادم RPC وRLS وسياسات Realtime غير موجودة في النسخة، وبالتالي لا يمكن تأكيد الصلاحيات أو السعة أو انتهاء الغرف على الخادم.

## خريطة المصدر

| الرمز | المصدر | مسؤوليته |
|---|---|---|
| N1 | [PartyRepository.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/features/party/PartyRepository.kt:52) | حالة الجلسة، RPC، الحضور، publish/accept، إعادة الانضمام، انتظار buffering |
| N2 | [PartyApi.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/features/party/PartyApi.kt:20) | أسماء RPC ومعاملاتها |
| N3 | [PartyChannel.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/features/party/PartyChannel.kt:16) | قناة Realtime ورسائل broadcast/presence |
| N4 | [PartyModels.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/features/party/PartyModels.kt:11) | schema client، media/source/playback/member/presence/error |
| N5 | [PartyClock.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/features/party/PartyClock.kt:7) | ساعة monotonic مثبتة بتوقيت الخادم |
| N6 | [PartySync.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/features/party/PartySync.kt:17) | drift، nudge، seek، ترتيب الأوامر، coordinator، behind |
| N7 | [PlayerScreenRuntimeParty.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/features/player/PlayerScreenRuntimeParty.kt:90) | تطبيق أوامر الغرفة على المشغّل ومراقبة حالته |
| N8 | [PartyScreen.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/features/party/PartyScreen.kt:84) | إدخال الرمز، preview، join، صفحة الغرفة |
| N9 | [PartyChat.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/features/party/PartyChat.kt:46) | إرسال optimistic، history، dedup، retry، unread |
| N10 | [PartySourceMatch.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/features/party/PartySourceMatch.kt:5) | مطابقة مصدر المضيف مع مصادر الجهاز |
| N11 | [StreamDestination.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/StreamDestination.kt:761) | إبراز المصدر المطابق وعرض المصدر المشترك |
| N12 | [AppUrlBridge.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/core/deeplink/AppUrlBridge.kt:70) | تحليل روابط الدعوة |
| N13 | [PlayerScreenRuntimeGestureActions.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/features/player/PlayerScreenRuntimeGestureActions.kt:155) | ربط play/pause/seek/speed والgesture بحراسة Party |
| N14 | [PlayerScreenRuntimeEffects.kt](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/features/player/PlayerScreenRuntimeEffects.kt:326) | منع startup resume من منافسة موضع Party وحراسة auto-next/skip |

## رحلة الإنشاء والانضمام

1. زر Party داخل المشغل يستدعي N7:208 `startParty`، ويصنع `PartyMedia` من meta type/id وvideo id والحلقة والموسم وصور العنوان ومعلومات المصدر (N7:146).
2. N1:229 يتحقق من capability `watchParty` ومن حساب Authenticated غير anonymous. الاسم من profile النشط، محدود إلى40 حرفًا؛ avatar يسمح HTTPS وبحد512 حرفًا؛ اللون hex سداسي؛ device ID من `SyncClientIdentity` (N1:642). الخروج من الحساب/التحول إلى anonymous يوقف الجلسة محليًا (N1:90).
3. `watch_party_create` يعيد PartySnapshot، ويحفظ العميل party/member ID والمضيف والأعضاء وmedia/playback في StateFlow. يبدأ session scope وقناة وحلقة heartbeat وclock/coordinator والدردشة. تنفّذ create/join تحت Mutex وعلى dispatcher محدود إلى مسار واحد (N1:229،260).
4. الرمز6 أحرف من `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`، uppercase مع حذف أي شيء خارج الأبجدية؛ عرضه `ABC DEF`. الكود مُستلم من الخادم، ولا يولده العميل. الدعوة الافتراضية `https://nuvio.tv/party/<code>`؛ الخادم المخصص يستخدم `nuvio://party/<code>` (N1:704).
5. N12 يقبل https فقط على `nuvio.tv/party/<code>` أو scheme `nuvio` وhost `party`؛ يدعم code في المسار أو query. يحتفظ الرابط المنتظر في StateFlow داخل الذاكرة.
6. N8:239 يمنع شاشة الانضمام محليًا إذا تعذر الاستخدام، ثم preview يعرض media والمضيف وعدد الأعضاء والسعة. `isFull` يعتمد على `max_members` القادم من الخادم. join يحتاج ضغط submit؛ preview من الرابط لا يعني انضمامًا تلقائيًا. بعد نجاح join تعرض شاشة تأكيد ثم تفتح media بعد1600ms (N8:102،262).
7. فتح media من [MainAppContent.kt:1030](C:/Users/hosea/projects/app/player-refereences/NuvioMobile/composeApp/src/commonMain/kotlin/com/nuvio/app/MainAppContent.kt:1030) يحسب موضع Party المتوقع، يمرره إلى launchPlaybackWithDownloadPreference، ويطلب `manualSelection=true`. لذلك الانضمام ليس تحميل رابط المضيف تلقائيًا.

## عقد RPC المرصود في العميل

كلها `SupabaseProvider.client.postgrest.rpc`. لا توجد تعريفات SQL لها هنا؛ الأسماء دليل على ما يطلبه العميل، وليست دليلًا على قواعد الخادم.

| RPC exact | المعاملات المرئية |
|---|---|
| `watch_party_create` | p_device_id, p_display_name, p_avatar_url, p_avatar_color, p_media, p_playback |
| `watch_party_join` | p_code + identity نفسها |
| `watch_party_preview` | p_code |
| `watch_party_heartbeat` | p_party_id, p_device_id |
| `watch_party_update` | p_party_id, p_device_id، وp_media/p_playback اختياريان |
| `watch_party_leave` | p_party_id, p_device_id |
| `watch_party_end` | p_party_id, p_device_id |
| `watch_party_set_host_only` | p_party_id, p_device_id, p_host_only |
| `watch_party_remove_member` | p_party_id, p_device_id, p_member_id |
| `watch_party_send_message` | p_party_id, p_device_id, p_body, p_client_id |
| `watch_party_list_messages` | p_party_id, p_device_id، p_after اختياري |
| `watch_party_clock` | لا معاملات |
| `watch_party_enabled` | لا معاملات |

`PartySnapshot`: party، members، member_id، server_time_ms، error، ok. `PartyInfo`: id/code/host_member_id/host_only/media/playback/max_members. قيمة max_members الافتراضية في model هي3، لكن الخادم يستطيع إرجاع غيرها؛ **لا يصح وصف3 بأنه حد الخدمة المثبت**. error mapping: party_not_found، party_full، removed/not_member، party_ended، rate_limited، unavailable؛ غيرها Network. وجود rate_limited لا يثبت معدلًا أو خوارزمية server معينة (N2،N4).

## النقل الفوري والحضور

N3 يفتح `watch-party:<partyId>` بـ`isPrivate=true` وpresence key=`memberId`. `receiveOwnBroadcasts=false` و`acknowledgeBroadcasts=false`؛ يربط listeners قبل subscribe، والاشتراك لا يحجب إلى أن يتصل. send/track يتجاهلان الإرسال إن لم تكن الحالة SUBSCRIBED.

الأحداث exact: `state`, `state_request`, `status`, `control`, `member_joined`, `member_left`, `ended`, `media`, `stream`, `chat`.

- state: PartyPlayback؛ status: PartyPresence (browsing/loading/buffering/ready/behind + media_key + behind_ms).
- state_request: يطلب snapshot فوريًا من الأعضاء؛ يردون بـstatus وstate، ويرسل المضيف shared stream إذا مُفعّلًا.
- member_joined: يستدعي heartbeat للحصول على الأعضاء؛ member_left يحدّث القائمة ويستقبل host_member_id جديدًا من الحدث. مغادرة المضيف تمسح shared stream.
- control: يغيّر host_only؛ media يغيّر العنوان/الحلقة؛ ended يوقف الجلسة، ويمكن أن يضبط feature disabled.
- reconnect: عند الاتصال يعيد track/status/state، يطلب state، ويجدد history مع retry للفاشل (N1:316). عند الانقطاع يمسح الحضور البعيد ويعرض reconnecting. لم ينفذ الكود هنا backoff خاصًا؛ إعادة اتصال transport متروكة لمكتبة Supabase. heartbeat كل دقيقتين (N1:544،695).
- `not_member` في snapshot يطلق join مرة أخرى برمز الغرفة؛ فشل الانضمام ينهيها محليًا أو يعلن Removed؛ تغيّر member ID يعيد إنشاء session مع playback المحلي الموجود (N1:597). لا يحفظ هذا المسار جلسة الغرفة على القرص.
- `leave` يوقف محليًا أولًا ثم يطلب leave. `end` ينتظر نجاح RPC قبل stop. إيقاف session يلغي jobs ويزيل channel ويمسح playback/sharedStream/chat (N1:134،144،289).

## نموذج المزامنة

`PartyPlayback = {seq, member_id, paused, position_ms, rate, at, media_key, waiting}`. `media_key` من lowercase metaType وmetaId والموسم والحلقة بفاصل `|`؛ يتجاهل تفاصيل المصدر عمدًا (N4:80).

الموضع المتوقع إذا كان paused هو position_ms؛ وإلا `position_ms + max(0, nowMs-at) * rate`، مع clamp إلى0 وإلى duration إن كانت موجبة (N6:27). الأوامر تتقدم بـseq، ويُكسر التعادل بمقارنة member_id النصية، وليس بترتيب وصول الشبكة (N6:38).

N5 يثبت توقيت server على ساعة monotonic؛ العينة تقدّر server_now=`server_time+RTT/2` ويقبل فقط RTT الأقل أو المساوي لأفضل RTT سابق. عند البداية تستخدم server_time_ms للـsnapshot، ثم4 عينات clock يفصلها400ms (N1:560). قبل التثبيت يرجع wall clock. هذا يقلل أثر تغيير ساعة الجهاز بعد التثبيت لكنه يفترض latency متناظرًا تقريبًا، ولم يُقَس فعليًا.

| التصحيح | القيم من المصدر |
|---|---|
| بدء nudge عند التشغيل | drift أكبر من250ms |
| إيقاف nudge بعد بدئه | drift في حدود80ms |
| nudge | base rate ×0.95 عند التقدم، ×1.05 عند التأخر |
| hard seek | drift أكبر من1500ms |
| حالة paused | seek فقط إذا الفرق أكبر من500ms |
| حلقة المشغل |250ms |
| فاصل محاولات التصحيح |500ms |
| انتظار استقرار seek |2500ms |
| تعويض تأخر seek | lead متعلم، بين0 و3000ms |
| persist بعد آخر publish |1500ms debounce |

N7:399 يطبق حالة جديدة فورًا؛ أول حالة أو الرجوع من الخلفية يجبر إعادة التطبيق. قد يعمل seek عند command جديد لفرق أكبر من500ms، بينما threshold1500ms يخص حلقة التصحيح المستمرة؛ لا تخلط بين المسارين. يتجنب تصحيح drift أثناء loading/scrubbing/ended أو media غير مطابق أو error أو الخلفية دون playback مدعوم. يعيد rate الأساس عند زوال nudge أو الخروج. N14 يمنع startup resume العادي عند وجود حالة Party حتى لا ينافسها.

N1:494 ينشر state سريعًا ثم يؤجل RPC update؛ يضبط rate محليًا بين0.25 و4، position غير سالب، وseq+1. accept يرفض media_key غير مطابق والأوامر الأقدم؛ في host_only يرفض member_id غير المضيف. هذه قيود عميل، ولا تثبت سلطة مرسل broadcast.

## الصلاحيات والانتظار والعودة للحاق

- `canControl = !hostOnly || isHost`؛ افتراضي hostOnly=false، لذلك أي عضو يستطيع نشر play/pause/seek/rate في الوضع الجماعي. تغيير media، تفعيل sharing، وتغيير host_only محروسة محليًا للمضيف (N1:162،173،195؛ N4:217).
- N13 يربط play/pause/seek/speed والتايملاين بحراسة Party؛ N7:252 يربط system controls بالمنطق نفسه. auto-next/auto-skip في N14 يحترمان lock. ليست الميزة مجرد تعطيل زر واحد.
- العضو المقفول يمكنه pause محليًا أو الرجوع وراء الغرفة، فيدخل `partyBehind`؛ لا يوقف الآخرين. محاولة القفز للأمام أثناء التزامن تُمنع. عند التشغيل ويصبح gap<=2000ms يعاود التزامن؛ توجد action للحاق فوريًا. Behind لا يوقف الغرفة (N6:85؛ N7:111،379).
- coordinator: المضيف إذا حاضر؛ في الوضع الجماعي عند غيابه أول عضو online وفق ترتيب members؛ في host_only يبقى المضيف coordinator حتى لو غائب. هذا تنسيق انتظار محلي، وليس إثباتًا لانتخاب المضيف الجديد على الخادم (N6:66).
- الحالة Loading أو Buffering لنفس media_key توقف الغرفة بواسطة coordinator؛ buffering لا يعلن قبل مرور1000ms. يفحص coordinator كل500ms، مع سماح3 ثوان بعد resume. ينتظر15 ثانية كحد ثم يعاود التشغيل ويتجاهل الأعضاء المنتظرين مؤقتًا، ويزيل تجاهلهم عند Ready. أعضاء browsing/behind أو media آخر لا يوقفونها (N1:568،N6:96،N7:337).
- عند خروج player ينشر browsing؛ إذا كان لا أحد آخر يشاهد العنوان وكانت الغرفة تعمل، يحاول pause. النشر يظل خاضعًا لـcanControl (N7:478).

## المصادر ومشاركة الروابط

N10 يطابق بالترتيب: infoHash مع fileIdx عندما كلا الفهرسين معروفان؛ وإلا filename دون حساسية للحالة؛ وإلا addonId+label. إذا توفر hash في الطرفين واختلف فلا يسقط إلى filename. المطابقة لا تثبت نسخة/cut/duration متطابقة، وتظل علامة إرشادية في source picker (N11:770).

المشاركة اختيار منفصل للمضيف. `PartyStream` يحمل URL، request headers، response_headers، وصف/اسم add-on/logo/file/bingeGroup/badges. يُرسل `stream` عبر القناة فقط في هذا المسار؛ لا يدخل `PartyMedia` أو `watch_party_update`. عند reconnect يعاد إرساله من ذاكرة المضيف. المتلقي يقبل member_id المزعوم للمضيف وURL قابلًا للمشاركة، ثم يعرضه كصف إضافي في picker. اختيار الصف المشترك لا يحفظه لإعادة الاستخدام العادي (`saveForReuse=false` في N11:813).

N7:169 يشترط HTTP(S) مصدرًا منفردًا دون audio URL منفصل. regex في N4:76 يرفض localhost و127.* و0.0.0.0 و[::1]، ولا يرفض عمومًا RFC1918 أو DNS داخليًا أو credentials في URL. لا يوجد في هذه الدالة redaction للترويسات، وقد تحتوي ترويسات المورد/الرابط على صلاحيات خاصة. هذه ملاحظة ثابتة عن البيانات المرسلة، وليست إثباتًا لتسرب حي أو استغلال.

## الدردشة

N9 يحد الرسالة إلى500 حرف بعد trim، ويولّد client_id عشوائيًا من20 حرفًا. يضيفها فورًا Sending ثم يطلب RPC send. النجاح يدمج الرد؛ الفشل Failed مع retry يدوي وأيضًا عند reconnect. first history load لا يزيد unread، اللاحق يزيده للرسائل الجديدة من الآخرين إن كانت المحادثة مغلقة؛ فتحها يصفر العداد.

history يستخدم after=آخر message ID معروف، ويتعامل مع صفحة100 عنصر بوصفها نافذة catch-up تستبدل الأقدم لتجنب فجوة. يحتفظ بآخر200 رسالة في العميل. dedup بحسب server id، وclient_id يربط تأكيد رسالة المستخدم بالصف optimistic ويحافظ على key. لا يُسمح لمجرد client_id من رسالة ليست mine باستبدال pending الخاص بالمستخدم. ترتب المؤكدة بحسب id وتبقي pending أسفلها. **حد100 هنا افتراض catch-up client، وحد200 ذاكرة client؛ لا يثبتان retention قاعدة البيانات** (N9:140،181،231).

## المخاطر والأسئلة غير المحسومة

| المسألة | ما أثبته المصدر | ما بقي مجهولًا |
|---|---|---|
| التفويض | حساب غير anonymous، host-only guard وprivate channel مطلوبان | auth.uid membership/RLS/Realtime policies وربط device_id بالحساب |
| سلطة broadcast | state/status/stream تقرأ member_id من payload؛ بعض الأحداث تغيّر الحالة مباشرة | هل الخادم يمنع انتحال member/host أو تمرير control/media/end مزور؟ |
| المنافسة | ترتيب deterministic بالـseq ثم member_id | هل RPC يتحقق seq/rate/timestamp ويمنع عضوًا من قفزة seq غير منطقية؟ |
| السعة | max_members من snapshot، default model=3 | الحد الحالي الحقيقي، quota، error على السباق |
| انتهاء الغرفة | heartbeat كل دقيقتين، ended/not_member handling | TTL، cleanup، retention chat، مدة الحظر بعد remove |
| انقطاع الشبكة | reconnect يعيد state/history وheartbeat يعيد snapshot | التسليم والترتيب أثناء انقطاع طويل، نجاح rejoin عند خادم فعلي |
| توافق النسخ | media identity وصيغ metadata | مطابقة البروتوكول مع Harbor أو دعم أي إصدار منشور |
| المنصات | طبقة Party في commonMain وsystem-control interface | تنفيذ Android/iOS، الخلفية، PiP، external player، دقة seek/rate الفعلية |
| سلامة المصدر | source hash واسم الملف والهيدر يمكن نقلها | صلاحية الرابط على IP عضو آخر، auth headers، اختلاف cut/duration |

لا يوجد server schema في النطاق المحلي؛ لا تدّعِ أن إضافة client مماثل في NOVA تكفي. يحتاج التنفيذ المستقل backend موثقًا بتفويض server-side، ترتيب أوامر، انتهاء غرف، rate limits، واختبارات جهازين على الأقل.

## الاختبارات الموجودة وحالة الأسئلة

الموجود في commonTest: `PartySyncTest.kt` عدد33 `@Test`، `PartyStreamTest.kt` عدد4، `PartyChatTest.kt` عدد9؛ المجموع46 تعريف اختبار. يغطي المصدر clock/correction/order/coordinator/behind/preview/code، قواعد URL وتحويل stream، وmerge/retry state في chat. **لم تُشغّل في هذا الفحص**؛ وجودها لا يثبت نتيجة النجاح أو سلامة backend.

| السؤال | الحالة |
|---|---|
| رحلة create/join/invite/UI | مجاب من المصدر |
| RPC/events/models | مجاب من المصدر |
| clock/drift/coordinator/buffering/behind | مجاب من المصدر |
| player command/system gesture integration | مجاب من المصدر |
| اختيار/مطابقة/مشاركة source | مجاب من المصدر |
| chat/reconnect/leave | مجاب من المصدر |
| RLS/authorization/TTL/server quotas | غير محسوم؛ server implementation غائب |
| حزمة منشورة مطابقة/REA decompilation لـNuvio | غير محسوم؛ لا artifact مناسب محليًا |
| التشغيل الفعلي بين أجهزة/منصات | غير مختبر |
