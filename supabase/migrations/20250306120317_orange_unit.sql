/*
  # Update equipment table and add initial products

  1. Changes
    - Add unique constraint on equipment name
    - Add all initial products from the file
  
  2. Security
    - Enable RLS on equipment table
    - Add policies for public read access and admin write access
*/

-- Enable RLS
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;

-- Add policies
CREATE POLICY "Anyone can view equipment"
  ON equipment
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Only admins can insert equipment"
  ON equipment
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

CREATE POLICY "Only admins can update equipment"
  ON equipment
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

CREATE POLICY "Only admins can delete equipment"
  ON equipment
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Insert initial equipment data
INSERT INTO equipment (name, description, price, deposit, image, categories)
VALUES
  ('Odkurzacz przemysłowy', 'Profesjonalny odkurzacz przemysłowy z czterowarstwową filtracją cyklonową i gniazdem...', 30, 100, 'https://solrent.pl/wp-content/uploads/2025/01/odkurzacz-przemyslowy.png', ARRAY['budowlany']),
  ('Szlifierka mimośrodkowa', 'Szlifierka YATO 150MM, 350W ze zmienną prędkością obrotową, idealna do usuwania powłok malarskich...', 50, 100, 'https://solrent.pl/wp-content/uploads/2025/01/szlifierka-mimosrodkowa.png', ARRAY['budowlany']),
  ('Nagrzewnica gazowa 65kW', 'Nagrzewnica GEKO G80415 o mocy 65 kW, solidna i bardzo wydajna, z termostatem, w zestawie reduktor...', 50, 100, 'https://solrent.pl/wp-content/uploads/2025/01/nagrzewnica-gazowa-geko.png', ARRAY['budowlany']),
  ('Przecinarka do glazury', 'Pilarka do cięcia płytek ceramicznych, glazury i gresu, przecinarka ręczna 47 cali, szerokość cięcia 1200mm...', 50, 200, 'https://solrent.pl/wp-content/uploads/2025/01/gilotyna.png', ARRAY['budowlany']),
  ('Osuszacz powietrza 70L', 'Osuszacz powietrza HUMBERG HM-482 o wydajności 70 litrów na 24 godziny, przyspiesza wysychanie...', 40, 300, 'https://solrent.pl/wp-content/uploads/2025/01/osuszacz.png', ARRAY['budowlany']),
  ('Stopa wibracyjna', 'Stopa wibracyjna Dro-Masz DRB80K z silnikiem Loncin 168F, idealna do zagęszczania piasku, żwiru...', 110, 500, 'https://solrent.pl/wp-content/uploads/2024/10/OLX-audyt-energetyczny-64.png', ARRAY['budowlany']),
  ('Odkurzacz piorący', 'Odkurzacz piorący KARCHER PUZZI 10/1, dogłębnie czyści runo wykładziny, usuwając nieprzyjemny zapach...', 50, 300, 'https://solrent.pl/wp-content/uploads/2024/10/KARCHER-Puzzi-10-1-front-2.jpg', ARRAY['budowlany']),
  ('Podnośnik do płyt GK', 'Podnośnik HAGEN LFH4-11, usprawnia prace remontowo-wykończeniowe, pozwala podnieść płytę o wymiarach do 150 x 308 cm...', 30, 200, 'https://solrent.pl/wp-content/uploads/2024/10/OLX-audyt-energetyczny-54.png', ARRAY['budowlany']),
  ('Pilarka Ukosowa', 'Pilarka ukosowa METABO KGS 254M, lekka i precyzyjna z laserem, umożliwia precyzyjne przycinanie...', 70, 300, 'https://solrent.pl/wp-content/uploads/2024/10/OLX-audyt-energetyczny-49.png', ARRAY['budowlany']),
  ('Młotowiertarka', 'Młotowiertarka Bosch Professional GBH 240, moc 790 W, energia udaru 2,7J, uchwyt SDS-PLUS dla...', 40, 200, 'https://solrent.pl/wp-content/uploads/2024/10/OLX-audyt-energetyczny-43-1.png', ARRAY['budowlany']),
  ('Szlifierka kątowa', 'Szlifierka kątowa Bosch Professional GWS2200, kompaktowa i wydajna, waży 4,8 kg, zoptymalizowana...', 40, 200, 'https://solrent.pl/wp-content/uploads/2024/10/OLX-audyt-energetyczny-42.png', ARRAY['budowlany']),
  ('Zgrzewarka do rur PP', 'Zgrzewarka służy do polifuzyjnego zgrzewania rur i kształtek z tworzyw termoplastycznych podczas wykonywania instalacji: wody zimnej, wody ciepłej, centralnego ogrzewania.', 30, 200, 'https://solrent.pl/wp-content/uploads/2024/10/OLX-audyt-energetyczny-9.png', ARRAY['budowlany']),
  ('Szlifierka do gipsu', 'Szlifierka do gipsu Kaltmann K-S750W LED to wielofunkcyjne, wszechstronne narzędzie, które dzięki mocy 750 W i regulowanej prędkości obrotowej tarczy idealnie nadaje się do szlifowania gładzi i tynków.', 50, 200, 'https://solrent.pl/wp-content/uploads/2024/09/szlifierka.png', ARRAY['budowlany']),
  ('Agregat prądotwórczy', 'Agregat prądotwórczy, to urządzenie służące do wytwarzania energii elektrycznej. Znajduje zastosowanie, kiedy nie jest możliwe zasilanie obiektów budowlanych lub urządzeń z sieci energetycznej.', 70, 500, 'https://solrent.pl/wp-content/uploads/2024/09/agregat-prad.png', ARRAY['budowlany']),
  ('Przecinarka do styropianu', 'Maszyna przeznaczona do szybkiego cięcia styropianu w dowolnych płaszczyznach. Cięcie odbywa się za pomocą rozgrzanego drutu oporowego.', 40, 200, 'https://solrent.pl/wp-content/uploads/2024/09/gilotyna-1.png', ARRAY['budowlany']),
  ('Nóż termiczny', 'Profesjonalny nóż termiczny o wszechstronnym działaniu do cięcia płyt izolacyjnych i ociepleniowych ze styroduru, styropianu i polistyrenu.', 40, 100, 'https://solrent.pl/wp-content/uploads/2024/09/noz.png', ARRAY['budowlany']),
  ('Osuszacz powietrza 55L', 'Profesjonalne urządzenie o wysokiej wydajność osuszania do 55 litrów na dobę, idealnie sprawdzi się na placach budowy, w mieszkaniach, przy remontach.', 40, 300, 'https://solrent.pl/wp-content/uploads/2024/09/osuszacz.png', ARRAY['budowlany']),
  ('Nagrzewnica gazowa BLP 53M', 'Nagrzewnica BLP 53M to duża nagrzewnica gazowa z zapłonem manualnym przeznaczona do hali, zakładów produkcyjnych, warsztatów czy magazynów.', 40, 200, 'https://solrent.pl/wp-content/uploads/2024/09/BLP_53e-scaled.jpg', ARRAY['budowlany']),
  ('Kompresor olejowy', 'Kompresor Torpeda z indukcyjnym silnikiem 3kW został wyposażony w 2 tłoki w trybie V i butlę o pojemności 50 litrów.', 80, 300, 'https://solrent.pl/wp-content/uploads/2024/09/gr1b.png', ARRAY['budowlany']),
  ('Agregat tynkarski', 'Zestaw tynkarski przeznaczony do natrysku materiałów o dużej gęstości. Powiększona średnica przewodów pozwala na jeszcze lepszy transport materiału do pistoletu natryskowego.', 120, 1000, 'https://solrent.pl/wp-content/uploads/2024/09/Agregat-tynkarski.jpeg', ARRAY['budowlany']),
  ('Młot wyburzeniowy', 'Najmocniejszy (70 J) w swojej klasie młot wyburzeniowy, chłodzony olejem (5W30). Przeznaczony do wyburzania żelbetu.', 70, 500, 'https://solrent.pl/wp-content/uploads/2024/09/mlot.png', ARRAY['budowlany']),
  ('Zaciskarka REMS', 'Uniwersalne, poręczne elektronarzędzie do połączeń zaciskowych we wszystkich powszechnie używanych systemach.', 120, 1000, 'https://solrent.pl/wp-content/uploads/2024/09/p4b.jpg', ARRAY['budowlany']),
  ('Bruzdownica', 'Przeznaczona jest do wykonywania bruzd gotowych, nie wymagających dodatkowego kucia. Możliwość montażu nawet 5 tarcz pozwala uzyskać rowki o szerokości 8-42 mm.', 60, 300, 'https://solrent.pl/wp-content/uploads/2024/10/ca041a9f45ae84fc830e9beeabd9.jpeg', ARRAY['budowlany']),
  ('Wiertnica do betonu', 'Wiertnica do betonu ze statywem pochyłym, stworzona dla specjalistów z branży budowlanej i konstrukcyjnej.', 100, 500, 'https://solrent.pl/wp-content/uploads/2024/09/p2b.jpg', ARRAY['budowlany']),
  ('Rusztowanie typu PLETTAC', 'To niezwykle ekonomiczne rusztowanie do wszelkiego rodzaju prac budowlano-montażowych.', 50, 500, 'https://solrent.pl/wp-content/uploads/2024/09/p1b.jpg', ARRAY['budowlany']),
  ('Dmuchawa / Odkurzacz', 'Odkurzacz do liści YATO YT-85175 to praktyczne i funkcjonalne urządzenie do dmuchania. Znajduje zastosowanie zarówno w domu, ogrodzie, jak i w warsztacie lub garażu.', 30, 100, 'https://solrent.pl/wp-content/uploads/2025/01/odkurzacz.png', ARRAY['ogrodniczy']),
  ('Zagęszczarka 90kg', 'Zagęszczarka gruntu z silnikiem Loncin o wadze 90 kg. Idealna do zagęszczania nawierzchni brukowej, tłuczeni oraz różnego rodzajów gleb.', 100, 500, 'https://solrent.pl/wp-content/uploads/2024/09/zageszczarka.png', ARRAY['ogrodniczy']),
  ('Wiertnica glebowa', 'Wiertnice glebowe są niezastąpionym narzędziem w rolnictwie i budownictwie, umożliwiającym przeprowadzenie precyzyjnych otworów w ziemi.', 80, 300, 'https://solrent.pl/wp-content/uploads/2024/09/wiertnica.png', ARRAY['ogrodniczy']),
  ('Dmuchawa akumulatorowa', 'Mocna dmuchawa do liści zasilana akumulatorem systemu Yato 18V. Przycisk Turbo zwiększa przepływ osiowy.', 30, 100, 'https://solrent.pl/wp-content/uploads/2024/09/dmuchawa.png', ARRAY['ogrodniczy']),
  ('Siewnik', 'Siewnik to niezawodne i efektywne narzędzie ogrodnicze, które ułatwia proces siewu nasion oraz równomierne rozprowadzanie nawozów granulowanych.', 30, 100, 'https://solrent.pl/wp-content/uploads/2024/09/siewnik.png', ARRAY['ogrodniczy']),
  ('Wertykulator spalinowy', 'Wertykulator zapewniający moc 5 KM jest przeznaczony do pracy na powierzchni 3000 m2, waży 56kg.', 130, 500, 'https://solrent.pl/wp-content/uploads/2024/09/wertykulaor.png', ARRAY['ogrodniczy']),
  ('Walec ogrodowy 50 cm', 'Walec ogrodowy służy do wzmocnienia gleby przed siewem i po zasiewie – dzięki temu nasiona trawy pozostaną tam gdzie należy.', 40, 200, 'https://solrent.pl/wp-content/uploads/2024/09/walec-50.png', ARRAY['ogrodniczy']),
  ('Walec ogrodowy 75 cm', 'Walec ogrodowy sprawdzi się idealnie podczas przeróżnych prac ogrodniczych, m. in. podczas procesu wyrównywania gleby lub trawnika.', 60, 200, 'https://solrent.pl/wp-content/uploads/2024/10/OLX-audyt-energetyczny-1000-x-1500-px.png', ARRAY['ogrodniczy']),
  ('Niwelator rozsuwany', 'Profesjonalny niwelator terenu, który sprawdzi się głównie w trzech dziedzinach: ogrodnictwo, brukarstwo oraz jeździectwo.', 120, 500, 'https://solrent.pl/wp-content/uploads/2024/09/OLX-audyt-energetyczny-38.png', ARRAY['ogrodniczy']),
  ('Posypywarka', 'Posypywarka służy do sypania takich materiałów jak: substrat, torf, ziemia oraz piasek płukany 0-2mm.', 150, 500, 'https://solrent.pl/wp-content/uploads/2024/10/OLX-audyt-energetyczny-41.png', ARRAY['ogrodniczy'])
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price = EXCLUDED.price,
  deposit = EXCLUDED.deposit,
  image = EXCLUDED.image,
  categories = EXCLUDED.categories;