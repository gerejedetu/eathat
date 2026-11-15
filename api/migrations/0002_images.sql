-- Photos: a product's packshot and a dish's picture, shown by the app (https URLs).
ALTER TABLE products ADD COLUMN image_url TEXT;
ALTER TABLE recipes ADD COLUMN image_url TEXT;
