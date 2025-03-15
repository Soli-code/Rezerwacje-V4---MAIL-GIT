/*
  # Add performance indexes
  
  1. New Indexes
    - Indeks GiST dla sprawdzania nakładających się dat
    - Indeksy dla często używanych kolumn
*/

-- Indeks GiST dla sprawdzania dostępności
CREATE INDEX IF NOT EXISTS idx_equipment_availability_daterange
ON equipment_availability USING gist (equipment_id, tstzrange(start_date, end_date, '[]'));

-- Indeksy dla często używanych kolumn
CREATE INDEX IF NOT EXISTS idx_equipment_availability_equipment_id
ON equipment_availability(equipment_id);

CREATE INDEX IF NOT EXISTS idx_equipment_availability_dates
ON equipment_availability(start_date, end_date);