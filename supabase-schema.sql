-- ============================================
-- SQL Schema для приложения заказа соков
-- Supabase Version
-- ============================================

-- Таблица категорий
create table categories (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  display_order integer default 0,
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Таблица соков
create table juices (
  id uuid default gen_random_uuid() primary key,
  category_id uuid references categories(id) on delete cascade,
  name text not null,
  description text,
  image_url text,
  price decimal(10, 2) not null,
  volume_ml integer default 500,
  is_available boolean default true,
  available_date date default current_date,
  ingredients text[],
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Таблица пользователей
create table users (
  id uuid default gen_random_uuid() primary key,
  telegram_id bigint unique not null,
  username text,
  first_name text,
  last_name text,
  phone_number text,
  is_admin boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Таблица адресов доставки
create table delivery_addresses (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references users(id) on delete cascade,
  address text not null,
  apartment text,
  entrance text,
  floor text,
  comment text,
  is_default boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Таблица заказов
create table orders (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references users(id) on delete cascade,
  order_number text unique not null,
  status text default 'pending' check (status in ('pending', 'confirmed', 'preparing', 'delivering', 'completed', 'cancelled')),
  total_amount decimal(10, 2) not null,
  delivery_address_id uuid references delivery_addresses(id),
  delivery_address_text text,
  phone_number text not null,
  comment text,
  payment_method text default 'cash' check (payment_method in ('cash', 'card')),
  delivery_time timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Таблица позиций заказа
create table order_items (
  id uuid default gen_random_uuid() primary key,
  order_id uuid references orders(id) on delete cascade,
  juice_id uuid references juices(id),
  juice_name text not null,
  quantity integer not null check (quantity > 0),
  price decimal(10, 2) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Создаём индексы для улучшения производительности
create index idx_juices_category_id on juices(category_id);
create index idx_juices_available on juices(is_available, available_date);
create index idx_orders_user_id on orders(user_id);
create index idx_orders_status on orders(status);
create index idx_orders_created_at on orders(created_at desc);
create index idx_order_items_order_id on order_items(order_id);
create index idx_users_telegram_id on users(telegram_id);

-- Функция для автоматического обновления updated_at
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$ language plpgsql;

-- Триггеры для автоматического обновления updated_at
create trigger update_categories_updated_at before update on categories
  for each row execute procedure update_updated_at_column();

create trigger update_juices_updated_at before update on juices
  for each row execute procedure update_updated_at_column();

create trigger update_users_updated_at before update on users
  for each row execute procedure update_updated_at_column();

create trigger update_orders_updated_at before update on orders
  for each row execute procedure update_updated_at_column();

-- Функция для генерации номера заказа
create or replace function generate_order_number()
returns trigger as $$
begin
  new.order_number = 'ORD-' || to_char(new.created_at, 'YYYYMMDD') || '-' || lpad(nextval('order_number_seq')::text, 4, '0');
  return new;
end;
$$ language plpgsql;

-- Последовательность для номеров заказов
create sequence order_number_seq;

-- Триггер для автоматической генерации номера заказа
create trigger set_order_number before insert on orders
  for each row execute procedure generate_order_number();

-- ============================================
-- Row Level Security (RLS) - Упрощённая версия
-- ============================================

-- Категории - доступны всем для чтения
alter table categories enable row level security;

create policy "Anyone can view active categories" 
  on categories for select 
  using (is_active = true);

create policy "Service role can manage categories" 
  on categories for all 
  using (true);

-- Соки - доступны всем для чтения
alter table juices enable row level security;

create policy "Anyone can view available juices" 
  on juices for select 
  using (is_available = true);

create policy "Service role can manage juices" 
  on juices for all 
  using (true);

-- Пользователи - упрощённый доступ
alter table users enable row level security;

create policy "Anyone can insert users" 
  on users for insert 
  with check (true);

create policy "Users can view all users" 
  on users for select 
  using (true);

create policy "Service role can manage users" 
  on users for all 
  using (true);

-- Адреса доставки - упрощённый доступ
alter table delivery_addresses enable row level security;

create policy "Anyone can manage addresses" 
  on delivery_addresses for all 
  using (true);

-- Заказы - упрощённый доступ
alter table orders enable row level security;

create policy "Anyone can view orders" 
  on orders for select 
  using (true);

create policy "Anyone can create orders" 
  on orders for insert 
  with check (true);

create policy "Anyone can update orders" 
  on orders for update 
  using (true);

-- Позиции заказа - упрощённый доступ
alter table order_items enable row level security;

create policy "Anyone can view order items" 
  on order_items for select 
  using (true);

create policy "Anyone can create order items" 
  on order_items for insert 
  with check (true);

-- ============================================
-- Тестовые данные
-- ============================================

-- Категории
insert into categories (name, description, display_order) values
  ('Цитрусовые', 'Свежие соки из цитрусовых фруктов', 1),
  ('Ягодные', 'Соки из спелых ягод', 2),
  ('Овощные', 'Полезные овощные соки', 3),
  ('Миксы', 'Авторские комбинации', 4);

-- Соки (примеры)
insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url) 
select 
  c.id,
  'Апельсиновый фреш',
  'Свежевыжатый сок из сладких апельсинов',
  1.00,
  100,
  array['Апельсины'],
  'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=400'
from categories c where c.name = 'Цитрусовые';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select 
  c.id,
  'Грейпфрутовый',
  'Бодрящий сок из розового грейпфрута',
  1.00,
  100,
  array['Грейпфрут розовый'],
  'https://images.unsplash.com/photo-1609401662589-cdbb6ea0d484?w=400'
from categories c where c.name = 'Цитрусовые';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select 
  c.id,
  'Клубничный смузи',
  'Густой смузи из свежей клубники',
  1.00,
  100,
  array['Клубника', 'Банан', 'Йогурт'],
  'https://images.unsplash.com/photo-1505252585461-04db1eb84625?w=400'
from categories c where c.name = 'Ягодные';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select 
  c.id,
  'Морковный детокс',
  'Очищающий морковный сок с имбирем',
  1.00,
  100,
  array['Морковь', 'Имбирь', 'Лимон'],
  'https://images.unsplash.com/photo-1623065422902-30a2d299bbe4?w=400'
from categories c where c.name = 'Овощные';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select 
  c.id,
  'Зелёный энергия',
  'Микс зелени и фруктов',
  1.00,
  100,
  array['Шпинат', 'Огурец', 'Яблоко', 'Сельдерей', 'Лимон'],
  'https://images.unsplash.com/photo-1610970881699-44a5587cabec?w=400'
from categories c where c.name = 'Миксы';

-- ============================================
-- Готово!
-- ============================================

-- После выполнения этого скрипта:
-- 1. Проверьте данные в Table Editor
-- 2. Добавьте себя как администратора (is_admin = true)
-- 3. Начните использовать приложение!


-- ============================================
-- Миграция для упрощения заказов с Telegram
-- ============================================

-- Добавляем новые поля для хранения Telegram данных напрямую в заказах
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS telegram_user_id BIGINT,
  ADD COLUMN IF NOT EXISTS telegram_username TEXT,
  ADD COLUMN IF NOT EXISTS user_first_name TEXT,
  ADD COLUMN IF NOT EXISTS user_last_name TEXT;

-- Делаем user_id опциональным (nullable)
ALTER TABLE orders
  ALTER COLUMN user_id DROP NOT NULL;

-- Делаем phone_number опциональным (nullable)
ALTER TABLE orders
  ALTER COLUMN phone_number DROP NOT NULL;

-- Удаляем поля адреса (они больше не нужны)
ALTER TABLE orders
  DROP COLUMN IF EXISTS delivery_address_id,
  DROP COLUMN IF EXISTS delivery_address_text;

-- Добавляем индекс для telegram_user_id для быстрого поиска заказов пользователя
CREATE INDEX IF NOT EXISTS idx_orders_telegram_user_id ON orders(telegram_user_id);

-- Комментарии для документации
COMMENT ON COLUMN orders.telegram_user_id IS 'ID пользователя в Telegram';
COMMENT ON COLUMN orders.telegram_username IS 'Username пользователя в Telegram';
COMMENT ON COLUMN orders.user_first_name IS 'Имя пользователя из Telegram';
COMMENT ON COLUMN orders.user_last_name IS 'Фамилия пользователя из Telegram';
COMMENT ON COLUMN orders.phone_number IS 'Номер телефона из Telegram (если доступен)';
COMMENT ON COLUMN orders.comment IS 'Комментарий к заказу от пользователя';

-- ============================================
-- Готово!
-- ============================================



insert into categories (name, description, display_order) values
  ('All In', 'Популярный набор', 1),
  ('Vodka', 'На основе водки', 2),
  ('Barmen Special', 'Что-то сложное', 3),
  ('Мулы', 'Сочетание напитков с алкоголем и лаймом', 4),
  ('Виски', 'На основе виски', 5),
  ('Ром', 'На основе Рома', 6),
  ('Джин', 'На основе Джина', 7),
  ('Текила', 'На основе Текилы', 8);


-- ALL IN
insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Френч 75','Игристый коктейль на джине с лимоном',0.00,115,
array['Джин ','Просекко ','Сахарный сироп ','Лимонный сок '],
'https://images.cocktailwave.com/french-75.png'
from categories c where c.name = 'All In';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Арно Френч 75','Вариация French 75 на коньяке',0.00,150,
array['Коньяк ','Просекко ','Сахарный сироп ','Лимонный сок '],
'https://images.cocktailwave.com/french-75.png'
from categories c where c.name = 'All In';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Сайдкар','Классика на коньяке и апельсиновом ликёре',0.00,95,
array['Коньяк ','Куантро ','Сахарный сироп 5 мл','Лимонный сок '],
'https://images.cocktailwave.com/sidecar.png'
from categories c where c.name = 'All In';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Между простынями','Цитрусовый коктейль на коньяке и роме',0.00,110,
array['Коньяк ','Белый ром ','Куантро ','Лимонный сок '],
'https://source.unsplash.com/400x400/?cocktail,citrus'
from categories c where c.name = 'All In';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Long Island Iced Tea','Классический микс крепкого с колой',0.00,250,
array['Джин ','Текила ','Водка ','Ром ','Куантро ','Кола (долив)'],
'https://source.unsplash.com/400x400/?longisland,cocktail'
from categories c where c.name = 'All In';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Мартини','Сухой микс джина и водки',0.00,60,
array['Джин ','Водка '],
'https://source.unsplash.com/400x400/?martini,cocktail'
from categories c where c.name = 'All In';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Северное сияние','Водка с просекко и сиропом',0.00,155,
array['Водка ','Просекко 1','Сахарный сироп '],
'https://source.unsplash.com/400x400/?sparkling,cocktail'
from categories c where c.name = 'All In';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Порнозвезда','Сладко-кислый коктейль с маракуйей и игристым',0.00,130,
array['Водка ','Просекко ','Ликёр маракуйи ','Лаймовый сок '],
'https://source.unsplash.com/400x400/?passionfruit,cocktail'
from categories c where c.name = 'All In';


-- VODKA
insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Отвертка','Водка с апельсиновым соком',0.00,135,
array['Водка ','Апельсиновый сок '],
'https://source.unsplash.com/400x400/?screwdriver,cocktail'
from categories c where c.name = 'Vodka';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Белый русский','Сливочный коктейль на водке и кофейном ликёре',0.00,90,
array['Водка ','Кофейный ликёр ','Сливочный ликёр '],
'https://source.unsplash.com/400x400/?white-russian,cocktail'
from categories c where c.name = 'Vodka';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Черный русский','Водка с кофейным ликёром',0.00,60,
array['Водка ','Кофейный ликёр '],
'https://source.unsplash.com/400x400/?black-russian,cocktail'
from categories c where c.name = 'Vodka';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Космополитен','Водка, цитрус и клюква',0.00,85,
array['Водка ','Куантро ','Клюквенный сок ','Лаймовый сок '],
'https://source.unsplash.com/400x400/?cosmopolitan,cocktail'
from categories c where c.name = 'Vodka';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Трава у моря','Освежающий коктейль на водке с абсентом',0.00,140,
array['Водка ','Абсент 5 мл','Сахарный сироп ','Содовая '],
'https://source.unsplash.com/400x400/?absinthe,cocktail'
from categories c where c.name = 'Vodka';


-- BARMEN SPECIAL
insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Turbo девяностых','Авторский микс на джине/роме с настойкой',0.00,165,
array['Джин ','Тёмный ром ','Трипл сек ','Настойка «Лопух и Одуванчик» 1'],
'https://source.unsplash.com/400x400/?cocktail,bar'
from categories c where c.name = 'Barmen Special';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Turbo Killer','Авторский микс с маракуйей и «черноплодной» колой',0.00,193,
array['Джин ','Тёмный ром ','Ликёр маракуйи ','Мараскино 3 мл','Кампари ','Кола «Черноплодная рябина» 1'],
'https://source.unsplash.com/400x400/?campari,cocktail'
from categories c where c.name = 'Barmen Special';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Средиземноморская мелодия','Джин-тоник с лаймом и специями',0.00,120,
array['Джин ','Тоник ','Лаймовый сок ','Сахар','Корица'],
'https://source.unsplash.com/400x400/?gin-tonic,cocktail'
from categories c where c.name = 'Barmen Special';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Сиеста в Мехико','Текила с розовым лимонадом и базиликом',0.00,135,
array['Текила ','Розовый лимонад ','Красный базилик (ветка)'],
'https://source.unsplash.com/400x400/?tequila,cocktail'
from categories c where c.name = 'Barmen Special';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Штиль','Лёгкий микс на джине с абсентом и сиропом',0.00,173,
array['Джин ','Абсент 3 мл','Сахарный сироп 5 мл','Вода 1'],
'https://source.unsplash.com/400x400/?highball,cocktail'
from categories c where c.name = 'Barmen Special';


-- МУЛЫ (по формуле: алкоголь  + имбирное пиво 1 + лаймовый сок )
insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Московский мул','Водка, имбирное пиво и лайм',0.00,180,
array['Водка ','Имбирное пиво 1','Лаймовый сок '],
'https://source.unsplash.com/400x400/?moscow-mule,cocktail'
from categories c where c.name = 'Мулы';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Ямайский мул','Ром, имбирное пиво и лайм',0.00,180,
array['Тёмный ром ','Имбирное пиво 1','Лаймовый сок '],
'https://source.unsplash.com/400x400/?rum,cocktail'
from categories c where c.name = 'Мулы';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Джин мул','Джин, имбирное пиво и лайм',0.00,180,
array['Джин ','Имбирное пиво 1','Лаймовый сок '],
'https://source.unsplash.com/400x400/?gin,cocktail'
from categories c where c.name = 'Мулы';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Мексиканский мул','Текила, имбирное пиво и лайм',0.00,180,
array['Текила ','Имбирное пиво 1','Лаймовый сок '],
'https://source.unsplash.com/400x400/?mexican-mule,cocktail'
from categories c where c.name = 'Мулы';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Эдинбург мул','Виски, имбирное пиво и лайм',0.00,180,
array['Виски ','Имбирное пиво 1','Лаймовый сок '],
'https://source.unsplash.com/400x400/?whiskey,cocktail'
from categories c where c.name = 'Мулы';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Кентукки мул','Бурбон, имбирное пиво и лайм',0.00,180,
array['Бурбон ','Имбирное пиво 1','Лаймовый сок '],
'https://source.unsplash.com/400x400/?bourbon,cocktail'
from categories c where c.name = 'Мулы';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Новоорлеанский мул','Мул по базовой формуле',0.00,180,
array['Алкоголь ','Имбирное пиво 1','Лаймовый сок '],
'https://source.unsplash.com/400x400/?ginger-beer,cocktail'
from categories c where c.name = 'Мулы';


-- ВИСКИ
insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Old Fashioned','Классика на бурбоне с сиропом и биттером',0.00,55,
array['Бурбон ','Сахарный сироп ','Ангостура 2–3 деша'],
'https://source.unsplash.com/400x400/?old-fashioned,cocktail'
from categories c where c.name = 'Виски';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Sazerac','Бурбон с абсентом и биттерами',0.00,55,
array['Бурбон ','Абсент 1/4 барной ложки','Сахарный сироп ','Пишо биттер 2–3 деша'],
'https://source.unsplash.com/400x400/?sazerac,cocktail'
from categories c where c.name = 'Виски';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Модный виски коктейль','Виски с куантро, сиропом и ангостурой',0.00,82,
array['Виски ','Куантро ','Сахарный сироп 7 мл','Ангостура 1–2 деша'],
'https://source.unsplash.com/400x400/?whisky,cocktail'
from categories c where c.name = 'Виски';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Манхеттен','Виски/бурбон со сладким вермутом и биттером',0.00,90,
array['Бурбон (или виски для «Роб Роя») ','Сладкий вермут ','Ангостура 2–3 деша'],
'https://source.unsplash.com/400x400/?manhattan,cocktail'
from categories c where c.name = 'Виски';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Виски сауэр','Кисло-сладкий виски с лимоном',0.00,98,
array['Виски ','Лимонный сок ','Сахарный сироп '],
'https://source.unsplash.com/400x400/?whiskey-sour,cocktail'
from categories c where c.name = 'Виски';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Мятный джулеп','Бурбон, мята и много льда',0.00,93,
array['Бурбон ','Сахарный сироп ','Мята (4–5 веток)','Лёд (дроблёный)'],
'https://source.unsplash.com/400x400/?mint-julep,cocktail'
from categories c where c.name = 'Виски';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Бульвардье','Виски-классика с кампари и вермутом',0.00,105,
array['Виски ','Сладкий вермут ','Кампари '],
'https://source.unsplash.com/400x400/?boulevardier,cocktail'
from categories c where c.name = 'Виски';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Заставь рыдать бармена','Виски с колой',0.00,240,
array['Виски ','Кола 1'],
'https://source.unsplash.com/400x400/?whiskey,cola'
from categories c where c.name = 'Виски';


-- РОМ
insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Кубалибре','Ром, кола и лайм',0.00,225,
array['Ром ','Кола 1','Лаймовый сок '],
'https://source.unsplash.com/400x400/?cuba-libre,cocktail'
from categories c where c.name = 'Ром';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Тьма и буря','Тёмный ром с имбирным пивом',0.00,240,
array['Тёмный ром ','Имбирное пиво 1'],
'https://source.unsplash.com/400x400/?dark-and-stormy,cocktail'
from categories c where c.name = 'Ром';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Мохито','Белый ром, лайм и мята',0.00,80,
array['Белый ром ','Сахарный сироп ','Лайм (сок) ','Мята (4 шт.)'],
'https://source.unsplash.com/400x400/?mojito,cocktail'
from categories c where c.name = 'Ром';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Ураган','Двойной ром с цитрусом и маракуйей',0.00,165,
array['Светлый ром ','Тёмный ром ','Ликёр маракуйи ','Апельсиновый сок ','Лаймовый сок ','Гренадин '],
'https://source.unsplash.com/400x400/?hurricane,cocktail'
from categories c where c.name = 'Ром';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Птица джунглей','Ром, кампари и ананас',0.00,140,
array['Тёмный ром ','Кампари ','Ананасовый сок ','Лаймовый сок ','Сахарный сироп '],
'https://source.unsplash.com/400x400/?jungle-bird,cocktail'
from categories c where c.name = 'Ром';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Дайкири','Белый ром с лаймом и сиропом',0.00,93,
array['Белый ром ','Лаймовый сок ','Сахарный сироп '],
'https://source.unsplash.com/400x400/?daiquiri,cocktail'
from categories c where c.name = 'Ром';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Эль Президенте','Ромовый коктейль с вермутом и гренадином',0.00,78,
array['Белый ром ','Сухой вермут ','Кюрасао 8 мл','Гренадин 5 мл'],
'https://source.unsplash.com/400x400/?rum,cocktail,classic'
from categories c where c.name = 'Ром';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'А что так можно было?!','Ром с колой (вариация)',0.00,240,
array['Ром ','Кола 1'],
'https://source.unsplash.com/400x400/?rum,cola'
from categories c where c.name = 'Ром';


-- ДЖИН
insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Джин тоник','Классический джин с тоником',0.00,105,
array['Джин ','Тоник '],
'https://source.unsplash.com/400x400/?gin-tonic'
from categories c where c.name = 'Джин';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Негрони','Джин, кампари и сладкий вермут',0.00,90,
array['Джин ','Сладкий вермут ','Кампари '],
'https://source.unsplash.com/400x400/?negroni,cocktail'
from categories c where c.name = 'Джин';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Сухой мартини','Джин с сухим вермутом',0.00,70,
array['Джин ','Сухой вермут '],
'https://source.unsplash.com/400x400/?dry-martini,cocktail'
from categories c where c.name = 'Джин';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Том Коллинс','Джин, лимон, сироп и содовая',0.00,150,
array['Джин ','Сахарный сироп ','Лимонный сок ','Содовая '],
'https://source.unsplash.com/400x400/?tom-collins,cocktail'
from categories c where c.name = 'Джин';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Бронкс','Джин с вермутами и апельсином',0.00,70,
array['Джин ','Сухой вермут ','Сладкий вермут ','Апельсиновый сок '],
'https://source.unsplash.com/400x400/?gin,cocktail,orange'
from categories c where c.name = 'Джин';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Вазэктомия','Джин с клюквой, лимоном и тоником',0.00,178,
array['Джин ','Клюквенный сок ','Лимонный сок ','Тоник '],
'https://source.unsplash.com/400x400/?cranberry,cocktail'
from categories c where c.name = 'Джин';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Воскрешатель номер два','Коктейль на джине с вермутом и кюрасао',0.00,80,
array['Джин ','Сухой вермут ','Кюрасао ','Лимонный сок ','Абсент 1/4 барной ложки'],
'https://source.unsplash.com/400x400/?cocktail,classic'
from categories c where c.name = 'Джин';


-- ТЕКИЛА
insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Палома','Текила с грейпфрутом и содовой',0.00,105,
array['Текила ','Грейпфрутовый сок ','Содовая '],
'https://source.unsplash.com/400x400/?paloma,cocktail'
from categories c where c.name = 'Текила';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Текила Санрайз','Текила с апельсином и гренадином',0.00,150,
array['Текила ','Апельсиновый сок ','Гренадин '],
'https://source.unsplash.com/400x400/?tequila-sunrise,cocktail'
from categories c where c.name = 'Текила';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Маргарита','Текила, куантро и лайм',0.00,85,
array['Текила ','Куантро ','Лаймовый сок '],
'https://source.unsplash.com/400x400/?margarita,cocktail'
from categories c where c.name = 'Текила';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Батанга','Текила с лаймом и колой',0.00,175,
array['Текила ','Лаймовый сок ','Кола 1'],
'https://source.unsplash.com/400x400/?batanga,cocktail'
from categories c where c.name = 'Текила';

insert into juices (category_id, name, description, price, volume_ml, ingredients, image_url)
select c.id,'Храбрый бык','Текила с кофейным ликёром',0.00,45,
array['Текила ','Кофейный ликёр '],
'https://source.unsplash.com/400x400/?tequila,coffee,cocktail'
from categories c where c.name = 'Текила';
