# PunchClock - digitalna evidencija radnog vremena

**Zadatak za praksu** | Flutter · Supabase · PostgreSQL · GPS Geofencing

---

| **Naziv projekta** | PunchClock |
| --- | --- |
| **Tehnologije** | Flutter (Dart), Supabase (PostgreSQL), GPS/Geolocation |
| **Backend za izvještaje** | .NET API (kasnija faza) |

## 1. Uvod

Cilj ovog zadatka je razviti mobilnu aplikaciju za evidenciju dolazaka i odlazaka sa posla - digitalnu verziju klasičnih punch kartica.

Sustav se sastoji od dva dijela:

- **Mobilna aplikacija (Flutter)** - zaposlenici se prijavljuju/odjavljuju na dodijeljene lokacije prema rasporedu koji im je definirao admin. Aplikacija automatski bilježi GPS koordinate i vrijeme te provjerava da li je zaposlenik na pravom mjestu u pravo vrijeme.
- **Admin panel (Flutter web ili poseban ekran)** - administrator kreira lokacije, definira rasporede za zaposlenike (tko, gdje, kada), pregledava evidenciju i upravlja korekcijama.

U kasnijoj fazi dodaje se **.NET Minimal API servis** za generiranje izvještaja i export podataka po zaposlenicima, lokacijama i vremenskim periodima.

---

## 2. Koncept sustava

### 2.1 Uloge

**Admin** može:

- Kreirati i uređivati lokacije (naziv, adresa, GPS koordinate, dozvoljeni radius)
- Kreirati rasporede: definirati za svakog zaposlenika na kojoj lokaciji treba biti, kojim danima, u koje vrijeme i sa kojom tolerancijom
- Pregledavati evidenciju svih zaposlenika (tko je kada došao, na koju lokaciju, da li je bio unutar zone, da li je bio na vrijeme)
- Korigirati punch zapise (npr. zaposlenik zaboravio Check Out)
- Odobravati/odbijati zahtjeve za odsustvo
- Pregledavati audit log notifikacija (koje obavijesti su poslane, kome, kada)
- Pokretati izvještaje i export podataka

**Zaposlenik** može:

- Vidjeti svoje rasporede (gdje i kada treba biti)
- Napraviti Check In / Check Out na lokaciji prema rasporedu
- Registrirati pauzu (Break Start / Break End)
- Primiti push obavijest kada se približi vrijeme za prijavu/odjavu
- Pregledati svoju historiju dolazaka
- Podnijeti zahtjev za odsustvo (godišnji, bolovanje, slobodan dan)

### 2.2 Glavni tok - zaposlenik

1. Zaposlenik otvori aplikaciju i loguje se (email + password)
2. Vidi danas aktivan raspored: lokacija X, smjena 08:00–16:00
3. Kad dođe na lokaciju, klikne **Check In** - aplikacija dohvata GPS, provjerava geofence i vrijeme prema rasporedu, te šalje zapis u bazu
4. Tokom dana može registrirati pauzu (**Break Start** / **Break End**)
5. Kad odlazi, klikne **Check Out** - isto kao Check In
6. Ako je unutar tolerancije (npr. ±15 min) i unutar radiusa, punch je "validan"; inače se bilježi kao "izvan okvira" ali se ne blokira - zaposlenik unosi razlog ako je kasni dolazak ili rani odlazak
7. Zaposlenik može pregledati svoju historiju i podnijeti zahtjev za odsustvo

### 2.3 Glavni tok - admin

1. Admin se loguje i vidi dashboard sa pregledom današnjih prijava po lokacijama
2. Kreira lokacije sa GPS koordinatama i radiusom
3. Kreira rasporede: "Zaposlenik Marko, lokacija Sjedište, pon–pet, 08:00–16:00, tolerancija ±15 min, pauza 30 min, važi od 01.04. do 30.06."
4. Pregledava evidenciju: filtrira po zaposleniku, lokaciji, datumu
5. Ako zaposlenik zaboravi Check Out, admin kreira korekciju (originalni zapis ostaje netaknut)
6. Odobrava ili odbija zahtjeve za odsustvo
7. Pregledava audit log notifikacija - vidi koje obavijesti su poslane kojim zaposlenicima
8. Pokreće izvještaje (kasnija faza - .NET servis)

### 2.4 GPS Geofencing

Aplikacija pri svakom Check In/Out dohvata GPS koordinate uređaja i izračunava udaljenost od centra lokacije koristeći **Haversine formulu**. Ako je udaljenost veća od definiranog radiusa, punch se bilježi ali se označava kao izvan geofence-a. Na UI-ju se prikazuje upozorenje.

### 2.5 Vremenski okvir

Raspored definira očekivano vrijeme dolaska i odlaska. Tolerancija (npr. ±15 min) određuje prihvatljivi prozor. Ako zaposlenik napravi Check In u periodu 07:45–08:15 za smjenu koja počinje u 08:00, prijava je "na vrijeme". Izvan tog okvira, bilježi se kao "kasni dolazak" ili "rani dolazak" - ne blokira se, ali zaposlenik mora unijeti razlog.

### 2.6 Pauze

Zaposlenik može registrirati pauzu klikom na **Break Start** i **Break End**. Raspored definira očekivano trajanje pauze (npr. 30 min). Pauza se oduzima od ukupnog radnog vremena pri kalkulaciji efektivnih sati.

### 2.7 Obavijesti - triggeri i logika

Notifikacije nisu samo vremenski podsjetnci - sustav treba biti pametan i reagirati na kombinaciju lokacije i vremena. Postoje 4 triggera za notifikacije:

**Trigger 1: Zaposlenik je na lokaciji ali se nije prijavio (geofence enter)**
Sustav detektira da je zaposlenik ušao u geofence zonu lokacije za koju ima aktivan raspored, ali nema Check In. Npr. zaposlenik dođe u ured u 07:55 ali zaboravi otvoriti app.
→ Notifikacija: "Nalazite se na lokaciji X - ne zaboravite se prijaviti."
→ Tehnički: OS-level geofence enter event + provjera rasporeda i postojećeg Check In-a.

**Trigger 2: Došlo je vrijeme za prijavu a zaposlenik nije na lokaciji (vremenski)**
Prema rasporedu, smjena počinje u 08:00, tolerancija je +15 min. U 08:15 zaposlenik nema Check In niti je detektiran unutar geofence-a.
→ Notifikacija: "Vaša smjena na lokaciji X je počela u 08:00 - niste se prijavili."
→ Tehnički: scheduled provjera na `work_start + tolerance`, ne zahtijeva GPS - čisto vremenski trigger.

**Trigger 3: Zaposlenik je napustio lokaciju bez Check Out-a (geofence exit)**
Zaposlenik ima aktivan Check In na lokaciji X, ali sustav detektira da je izašao iz geofence zone.
→ Notifikacija: "Napustili ste lokaciju X - ne zaboravite se odjaviti."
→ Tehnički: OS-level geofence exit event + provjera otvorenog Check In-a.

**Trigger 4: Kraj smjene a nema Check Out-a (vremenski)**
Smjena završava u 16:00, tolerancija je +15 min. U 16:15 zaposlenik još nema Check Out.
→ Notifikacija: "Vaša smjena na lokaciji X je završila - niste se odjavili."
→ Tehnički: scheduled provjera na `work_end + tolerance`, ne zahtijeva GPS.

**Dodatne notifikacije (ne vezane za triggere):**

- Kad admin odobri/odbije zahtjev za odsustvo
- Kad admin kreira ili promijeni raspored za zaposlenika
- Kad sustav automatski zatvori smjenu (vidi 2.9)

**Svaka poslata notifikacija se bilježi u `notifications` tabelu** - tip, sadržaj, trigger koji ju je izazvao, kome je poslana, da li je dostavljena, da li je pročitana. Admin može vidjeti kompletnu historiju notifikacija i filtrirati po zaposleniku, tipu i datumu.

### 2.8 Baterija i background location - tehnički pristup

Ovo je najvažniji tehnički izazov aplikacije. Continuous GPS tracking uništava bateriju (15–20% na sat), pa se **ne smije koristiti**. Umjesto toga, koristi se hibridni pristup:

**OS-level geofencing (za Trigger 1 i 3):** I Android i iOS imaju native geofencing API koji radi na nivou operativnog sustava, ne u aplikaciji. Registriraš krug (lat, lng, radius) i OS javi aplikaciji kad korisnik uđe ili izađe iz zone. Ovo troši minimalno baterije jer OS koristi kombinaciju cell tower triangulacije, WiFi fingerprintinga i GPS-a - pali precizni GPS samo kad je potrebno. Baterijski udarac je zanemariv - par posto dnevno.

**Scheduled local notifications (za Trigger 2 i 4):** Čisto vremenski triggeri koji ne zahtijevaju nikakav GPS. Na osnovu rasporeda, aplikacija zakazuje lokalne notifikacije unaprijed. Nula utjecaja na bateriju.

**Precizni GPS samo pri punch-u:** Puni GPS se pali jednokratno - samo u trenutku kad korisnik klikne Check In/Out. To je par sekundi, zanemarivo za bateriju.

**Implementacija na Flutteru:**

- `flutter_background_geolocation` ili `geofence_service` package za OS-level geofencing
- `flutter_local_notifications` za scheduled notifikacije
- `geolocator` za jednokratno dohvatanje precizne lokacije pri punch-u
- Pri loginu ili promjeni rasporeda, registrirati geofence zone za sve aktivne lokacije zaposlenika
- Kad raspored istekne ili se deaktivira, deregistrirati odgovarajuće geofence zone

**Važna ograničenja koja praktikant treba znati:**

- iOS ograničava broj aktivnih geofence zona na 20 po aplikaciji - ako zaposlenik ima više od 20 lokacija, treba implementirati rotaciju
- Android 12+ zahtijeva `ACCESS_BACKGROUND_LOCATION` permission koji korisnik mora eksplicitno odobriti u postavkama - app treba gracefully handlati slučaj kad korisnik ne odobri
- Background location permission je osjetljiva tema na obje platforme - Google Play i App Store imaju stroga pravila o tome zašto app treba background lokaciju. Treba jasno obrazložiti korisniku zašto je potrebna

### 2.9 Automatski Check Out

Ako zaposlenik zaboravi Check Out i ne reagira na notifikaciju (Trigger 3 i 4), sustav automatski zatvara smjenu nakon definiranog vremena (npr. kraj smjene + 60 min). Takav zapis se označava kao automatski zatvoren i generira se notifikacija o tome. Može se riješiti Supabase Edge Function-om ili CRON jobom.

---

## 3. Baza podataka (Supabase / PostgreSQL)

Praktikant treba sam definirati tipove kolona, primarne ključeve, foreign key-eve i constraint-e na osnovu opisa svake tabele. Ispod su opisane tabele sa svrhom svake kolone - bez konkretnih SQL tipova. Dio zadatka je istražiti PostgreSQL tipove i donijeti odluke o implementaciji.

### 3.1 `users`

Svi korisnici sustava. Sadrži osnovne podatke o korisniku i njegovu ulogu koja određuje da li je admin ili zaposlenik. Primarni ključ je Supabase Auth user ID.

Kolone: identifikator korisnika, email, puno ime, uloga (admin/employee), datum kreiranja računa.

### 3.2 `locations`

Lokacije na kojima se radi - sjedište firme, poslovnice, gradilišta, terenske lokacije. Svaka lokacija ima GPS centar i radius za geofencing. Lokacija se može deaktivirati bez brisanja.

Kolone: identifikator, naziv lokacije, adresa, GPS latitude i longitude centra, dozvoljeni radius u metrima, da li je lokacija aktivna, tko ju je kreirao, datum kreiranja.

### 3.3 `schedules`

Srce sustava - definira tko, gdje i kada treba biti. Admin kreira raspored koji kaže: "Zaposlenik X treba biti na lokaciji Y od 08:00 do 16:00, ponedjeljak–petak, sa tolerancijom ±15 min i pauzom od 30 min." Jedan zaposlenik može imati više rasporeda (npr. pon–sri lokacija A, čet–pet lokacija B). Raspored ima period važenja (datum od–do) tako da se mogu kreirati rasporedi unaprijed.

Kolone: identifikator, referenca na zaposlenika, referenca na lokaciju, očekivano vrijeme dolaska, očekivano vrijeme odlaska, dani u sedmici, tolerancija u minutama, očekivano trajanje pauze u minutama, datum početka važenja, datum kraja važenja, da li je raspored aktivan, tko ga je kreirao, datum kreiranja.

**Napomena o danima u sedmici:** praktikant treba odlučiti kako pohraniti dane - kao niz (array), kao odvojene boolean kolone za svaki dan, ili kao bitmask. Neka istraži prednosti i mane svakog pristupa.

### 3.4 `punches`

Svaki Check In, Check Out, Break Start i Break End je jedan zapis u ovoj tabeli. Veže se na korisnika i lokaciju, a opciono i na raspored prema kojem je punch napravljen. Sadrži GPS koordinate uređaja u trenutku punch-a, izračunatu udaljenost od centra lokacije, geofence status i vremenski status u odnosu na raspored.

Kolone: identifikator, referenca na korisnika, referenca na lokaciju, referenca na raspored (opciono), tip puncha (check_in / check_out / break_start / break_end), vrijeme puncha, GPS latitude i longitude uređaja, izračunata udaljenost od centra lokacije u metrima, da li je unutar geofence-a, vremenski status (on_time / early / late), razlog ako je kasni dolazak ili rani odlazak, da li je zapis automatski zatvoren od strane sustava, identifikator uređaja s kojeg je punch napravljen.

**Važno:** punch zapisi se nikad ne brišu i ne mijenjaju. Ako je potrebna ispravka, koristi se `punch_corrections` tabela.

### 3.5 `punch_corrections`

Korekcije punch zapisa. Kad admin treba ispraviti punch (npr. zaposlenik zaboravio Check Out, krivi tip puncha), originalni zapis u `punches` ostaje netaknut - ovdje se kreira korekcija sa novim vrijednostima. Ovo osigurava potpuni audit trail.

Kolone: identifikator, referenca na originalni punch zapis, novo korigirano vrijeme (opciono), novi tip puncha (opciono), razlog korekcije, admin koji je korigirao, datum korekcije.

### 3.6 `leave_requests`

Zahtjevi za odsustvo - godišnji odmor, bolovanje, slobodan dan. Bez ove tabele sustav ne može razlikovati "nije se prijavio" od "na godišnjem je". Zaposlenik podnosi zahtjev, admin odobrava ili odbija.

Kolone: identifikator, referenca na zaposlenika, datum početka odsustva, datum kraja odsustva, tip odsustva (vacation / sick / personal), status zahtjeva (pending / approved / rejected), komentar zaposlenika, komentar admina pri odobravanju/odbijanju, admin koji je obradio zahtjev, datum podnošenja, datum obrade.

### 3.7 `notifications`

Audit log svih notifikacija koje je sustav poslao korisnicima. Svaka push notifikacija - podsjetnik za prijavu, upozorenje za zaboravljeni Check Out, informacija o odobrenom odsustvu - bilježi se ovdje. Admin može vidjeti da je sustav upozorio zaposlenika koji tvrdi da "nije znao". Također služi za analizu: koliko notifikacija se šalje, koliko ih se čita, koji zaposlenici ignoriraju podsjetnike.

Kolone: identifikator, referenca na korisnika kojemu je poslana, tip notifikacije (schedule_reminder / missed_checkin / missed_checkout / leave_status / auto_checkout / system), naslov notifikacije, tekst poruke, referenca na raspored ako je vezana uz raspored (opciono), referenca na punch ako je vezana uz punch (opciono), da li je notifikacija uspješno dostavljena, da li je pročitana, kanal slanja (push / in_app / email), datum i vrijeme slanja, datum i vrijeme čitanja.

### 3.8 Row Level Security (RLS)

Obavezno uključiti RLS na svim tabelama:

- **users**: korisnik čita samo svoj profil; admin čita sve
- **locations**: svi autentificirani korisnici čitaju; samo admin kreira/uređuje
- **schedules**: zaposlenik vidi samo svoje rasporede; admin vidi sve i upravlja
- **punches**: zaposlenik čita/piše samo svoje zapise; admin čita sve
- **punch_corrections**: samo admin kreira; zaposlenik čita korekcije svojih puncheva
- **leave_requests**: zaposlenik čita/kreira samo svoje zahtjeve; admin čita sve i odobrava/odbija
- **notifications**: korisnik čita samo svoje notifikacije; admin čita sve

---

## 4. Faze razvoja

### Faza 1: Setup & UI osnove

**Zadaci:**

- Instalirati Flutter SDK, podesiti editor (VS Code ili Android Studio)
- Kreirati novi Flutter projekt
- Napraviti Login ekran sa email i password poljima
- Napraviti Home ekran (zaposlenik) sa placeholder prikazom današnjeg rasporeda i akcijskim dugmadima
- Napraviti Admin Dashboard ekran sa placeholder sadržajem
- Implementirati navigaciju i routing (GoRouter)
- Implementirati razlikovanje admin/employee prikaza (conditional routing)

**Očekivani rezultat:** Funkcionalna Flutter app sa ekranima za oba tipa korisnika. Sve hardkodirano - nema backend konekcije.

---

### Faza 2: Supabase integracija & Auth

**Zadaci:**

- Kreirati Supabase projekt na supabase.com (besplatni tier)
- Definirati tipove kolona i kreirati sve tabele prema opisima iz sekcije 3 putem SQL Editora
- Postaviti RLS pravila
- Dodati `supabase_flutter` package u projekt
- Implementirati registraciju i login sa Supabase Auth
- Po uspješnom loginu, dohvatiti korisnikov profil iz `users` tabele i usmjeriti na odgovarajući ekran (admin ili employee)
- Ručno u bazi kreirati jednog admin korisnika za testiranje

**Očekivani rezultat:** Korisnik se može registrovati, ulogovati, i biva preusmjeren na ispravan ekran ovisno o ulozi. Sve tabele postoje u bazi sa ispravnim relacijama i RLS pravilima.

---

### Faza 3: Admin - lokacije i rasporedi

**Zadaci:**

- Napraviti ekran za kreiranje nove lokacije (forma: naziv, adresa, lat/lng, radius)
- Za unos GPS koordinata: ručni unos ili interaktivna mapa (`flutter_map` + OpenStreetMap)
- Napraviti listu svih lokacija sa mogućnošću uređivanja i deaktiviranja
- Napraviti ekran za kreiranje rasporeda: odabir zaposlenika, lokacije, vremena dolaska/odlaska, dana u sedmici, tolerancije, trajanja pauze, perioda važenja
- Prikaz svih rasporeda sa filtriranjem po zaposleniku i lokaciji
- Implementirati CRUD operacije prema Supabase bazi za lokacije i rasporede

**Očekivani rezultat:** Admin može kreirati lokacije i rasporede. Zaposlenik ima definiran raspored - tko, gdje, kada. Sve se perzistira u bazi.

---

### Faza 4: Check In / Check Out sa GPS-om

**Zadaci:**

- Dodati `geolocator` package za GPS
- Na Home ekranu zaposlenika prikazati današnji raspored (lokacija, vrijeme, status)
- Implementirati Check In: dohvatiti GPS, izračunati udaljenost (Haversine), odrediti time_status prema rasporedu, snimiti u `punches`
- Implementirati Check Out sa istom logikom
- Implementirati Break Start / Break End
- Validacija: ne može Check In ako već ima otvoren Check In; ne može Break Start ako nema aktivan Check In; ne može Check Out ako ima otvorenu pauzu
- Ako je korisnik izvan geofence-a: prikazati upozorenje ali dozvoliti punch
- Ako je izvan vremenskog okvira: zatražiti razlog od zaposlenika

**Očekivani rezultat:** Zaposlenik može napraviti Check In/Out i registrirati pauze na lokacijama prema rasporedu. Svaki punch sadrži GPS koordinate, udaljenost, geofence status, vremenski status i opcioni razlog.

---

### Faza 5: Historija, korekcije i odsustva

**Zadaci:**

- **Zaposlenik:** ekran sa listom svih svojih punch-ova (datum, vrijeme, lokacija, tip, status)
- Filtriranje po datumu (date range picker) i lokaciji
- Dnevni pregled: prikaz parova Check In/Out sa izračunatim efektivnim radnim satima (minus pauze)
- Sedmični/mjesečni sumarni prikaz ukupnih sati
- Ekran za podnošenje zahtjeva za odsustvo i pregled statusa
- **Admin:** ekran sa pregledom svih zaposlenika - filtriranje po zaposleniku, lokaciji, datumu
- Admin vidi tabelu: zaposlenik | lokacija | Check In | Check Out | pauza | efektivni sati | geofence | time status
- Admin može kreirati korekciju puncha (originalni zapis ostaje, kreira se novi zapis u `punch_corrections` sa razlogom)
- Admin može odobriti/odbiti zahtjeve za odsustvo

**Očekivani rezultat:** Kompletna evidencija sa filterima, korekcijama i upravljanjem odsustvima. Admin ima potpunu sliku prisustva.

---

### Faza 6: Obavijesti i background geofencing

**Zadaci:**

- Dodati `flutter_background_geolocation` ili `geofence_service` package za OS-level geofencing
- Pri loginu zaposlenika, registrirati geofence zone za sve lokacije iz aktivnih rasporeda
- Implementirati Trigger 1 (geofence enter): kad zaposlenik uđe u zonu a nema Check In → notifikacija
- Implementirati Trigger 2 (vremenski): scheduled provjera na `work_start + tolerance`, ako nema Check In → notifikacija
- Implementirati Trigger 3 (geofence exit): kad zaposlenik izađe iz zone a ima otvoren Check In → notifikacija
- Implementirati Trigger 4 (vremenski): scheduled provjera na `work_end + tolerance`, ako nema Check Out → notifikacija
- Notifikacija zaposleniku kad admin odobri/odbije zahtjev za odsustvo
- **Svaku poslatu notifikaciju zapisati u `notifications` tabelu** sa svim relevantnim podacima (tip, trigger, sadržaj, korisnik, kanal, status dostave)
- Admin ekran: pregled svih poslatih notifikacija sa filtriranjem po zaposleniku, tipu, triggeru i datumu
- Implementirati automatski Check Out (Supabase Edge Function ili CRON) za zaboravljene odjave - i zabilježiti notifikaciju o tome
- Handlanje permisija: graceful fallback ako korisnik ne odobri background location - u tom slučaju rade samo vremenski triggeri (2 i 4)
- Dodati error handling na sve API pozive (try/catch, loading indikatori, snackbar poruke)
- Obraditi edge case-ove: nema interneta, GPS isključen, permission denied, iOS 20-geofence limit

**Očekivani rezultat:** Aplikacija pametno detektira da je zaposlenik na lokaciji ili da je vrijeme za prijavu i šalje odgovarajuće notifikacije. Svaka notifikacija je zabilježena u bazi sa statusom dostave. Admin može vidjeti kompletni audit log. Background geofencing radi bez značajnog utjecaja na bateriju.

---

### Faza 7: Poliranje & prezentiranje

**Zadaci:**

- Poboljšati UI/UX: konzistentni stilovi, ikone, animacije, responsivnost
- Testirati na stvarnom uređaju (ne samo emulator)
- Edge case testiranje: dupli klikovi, brzo prebacivanje ekrana, loš GPS signal
- Pripremiti kratku prezentaciju (5–10 min): arhitektura, demo, naučene lekcije, šta bi drugačije napravio

**Očekivani rezultat:** Stabilna, vizuelno uredna aplikacija spremna za demo.

---

### Faza 8: .NET Reporting servis (bonus / kasnija faza)

Ova faza se radi nakon što je Flutter aplikacija stabilna. Cilj je napraviti **.NET API** servis koji se spaja na istu Supabase PostgreSQL bazu i nudi napredne izvještaje i export.

**Zadaci:**

- Kreirati .NET 10 API projekt
- Spojiti se na Supabase PostgreSQL bazu putem EF Core (ili Npgsql direktno)
- Implementirati endpoint-e za izvještaje:

| Endpoint | Opis |
| --- | --- |
| `GET /api/reports/employee/{id}` | Izvještaj za jednog zaposlenika: ukupni sati, kasni dolasci, odsustva, lokacije, efektivno vs. planirano vrijeme |
| `GET /api/reports/location/{id}` | Izvještaj po lokaciji: svi zaposlenici, prisustvo po danima, popunjenost smjena |
| `GET /api/reports/daily?date=` | Dnevni izvještaj za sve lokacije i zaposlenike |
| `GET /api/reports/monthly?month=&year=` | Mjesečni sumarni izvještaj |
| `GET /api/reports/attendance-rate` | Stopa prisustva: planirano vs. ostvareno po zaposleniku/lokaciji |
| `GET /api/reports/notifications` | Pregled poslatih notifikacija sa filterima |
| `GET /api/export/csv?...` | Export filtriranih podataka u CSV |
| `GET /api/export/pdf?...` | Export izvještaja u PDF (QuestPDF) |
- Svaki izvještaj podržava filtriranje po: zaposleniku, lokaciji, datumskom rasponu
- PDF izvještaj sadrži: zaglavlje firme, tabelarni prikaz, sumarni red sa ukupnim satima, pauze, kasni dolasci

**Očekivani rezultat:** Funkcionalan .NET API koji generira izvještaje i exportira podatke.

---

## 5. Kriteriji prihvatljivosti

| # | Kriterij | Opis |
| --- | --- | --- |
| 1 | Registracija i login | Korisnik se može registrovati i ulogovati putem Supabase Auth |
| 2 | Razlikovanje uloga | Admin i zaposlenik vide različite ekrane i imaju različite mogućnosti |
| 3 | CRUD lokacija | Admin može kreirati, uređivati i deaktivirati lokacije |
| 4 | Rasporedi | Admin može kreirati rasporede: zaposlenik + lokacija + dani + vrijeme + tolerancija + pauza |
| 5 | Check In | Zaposlenik može napraviti Check In prema rasporedu sa GPS verifikacijom |
| 6 | Check Out | Zaposlenik može napraviti Check Out samo ako ima otvoren Check In |
| 7 | Pauze | Zaposlenik može registrirati Break Start / Break End |
| 8 | Geofence provjera | Aplikacija provjerava udaljenost i označava punch kao unutar/izvan zone |
| 9 | Vremenska provjera | Aplikacija provjerava da li je punch unutar tolerancije rasporeda |
| 10 | Razlog kašnjenja | Ako je punch izvan vremenskog okvira, zaposlenik mora unijeti razlog |
| 11 | Historija | Zaposlenik vidi svoju historiju, admin vidi historiju svih zaposlenika |
| 12 | Efektivni sati | Kalkulacija radnog vremena oduzima pauze od ukupnog vremena |
| 13 | Korekcije | Admin može korigirati punch bez brisanja originalnog zapisa |
| 14 | Odsustva | Zaposlenik može podnijeti zahtjev za odsustvo, admin odobrava/odbija |
| 15 | Obavijesti | Zaposlenik prima podsjetnike na osnovu rasporeda |
| 16 | Audit notifikacija | Svaka poslata notifikacija se bilježi u bazu sa statusom dostave i čitanja |
| 17 | Validacija | Aplikacija ne dozvoljava nedosljedne punch-ove (dupli Check In, Check Out bez Check In, itd.) |

---

## 6. Bonus zadaci (opcionalno)

| Feature | Opis |
| --- | --- |
| Interaktivna mapa | Prikaz svih lokacija na mapi sa geofence krugovima |
| Offline podrška | Lokalno spremanje punch-a ako nema interneta, sync kad se vrati konekcija |
| Dark mode | Podrška za tamni način prikaza |
|  |  |
| Dashboard grafovi | Admin dashboard sa grafikonima (prisustvo po danu, kasni dolasci, trend) |
| Kalendarski prikaz | Zaposlenik vidi mjesečni kalendar: zeleno = sve ok, žuto = kasni, crveno = odsutan, sivo = slobodan dan |
| Device tracking | Bilježenje device ID-a pri punch-u, upozorenje adminu ako isti korisnik koristi više uređaja u kratkom razmaku |
| .NET PDF izvještaji | Generirani PDF izvještaji sa zaglavljem firme i tabelarnim prikazom |
| Zakazani izvještaji | Automatski sedmični email izvještaj adminu |

---

## 7. Korisni resursi

**Flutter:**

- flutter.dev - Zvanična dokumentacija
- pub.dev - Flutter package repozitorij
- pub.dev/packages/supabase_flutter - Supabase Flutter SDK
- pub.dev/packages/geolocator - GPS package za jednokratno dohvatanje lokacije
- pub.dev/packages/flutter_background_geolocation - OS-level geofencing i background location (preporučeni za Trigger 1 i 3)
- pub.dev/packages/flutter_local_notifications - Lokalne/scheduled notifikacije (za Trigger 2 i 4)
- pub.dev/packages/flutter_map - OpenStreetMap mapa (besplatno, bez API ključa)

**Supabase:**

- supabase.com/docs - Zvanična dokumentacija
- supabase.com/docs/guides/getting-started/quickstarts/flutter - Flutter quickstart
- supabase.com/docs/guides/auth - Autentifikacija
- supabase.com/docs/guides/database - Baza i RLS

**GPS / Geofencing / Baterija:**

- Haversine formula - Za računanje udaljenosti između dvije GPS točke
- pub.dev/packages/geolocator - Uputstvo za GPS permisije na Android i iOS
- Android Geofencing API - developer.android.com/develop/sensors-and-location/location/geofencing
- Apple Core Location Monitoring - developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions
- Android 12+ background location - developer.android.com/develop/sensors-and-location/location/permissions (ACCESS_BACKGROUND_LOCATION zahtijeva poseban permission flow)

---

## 8. Napomene

- **Ne mora biti savršeno** - cilj je naučiti, ne napraviti produkcijski softver.
- **Koristi Git** - commitaj često, piši smislene commit poruke. Napravi GitHub repo od prvog dana.
- **Dokumentiraj** - piši komentare u kodu i vodi kratke bilješke o onome što učiš.
- **Google, Stack Overflow, AI alati** - slobodno koristi sve resurse. Bitno je da razumiješ kod koji pišeš.
- **Baza je tvoja odgovornost** - opisi tabela su namjerno bez tipova kolona. Istraži PostgreSQL tipove i sam definiraj shemu. Ovo je dio zadatka.