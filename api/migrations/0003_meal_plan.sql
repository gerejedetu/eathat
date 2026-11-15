-- The week's meals: which recipe is planned for which day, at noon or in the evening.
CREATE TABLE meal_plan (
  id         INTEGER PRIMARY KEY,
  day        TEXT NOT NULL CHECK (day GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
  slot       TEXT NOT NULL DEFAULT 'soir' CHECK (slot IN ('midi', 'soir')),
  recipe_id  INTEGER NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL
) STRICT;

CREATE INDEX meal_plan_day ON meal_plan(day);
