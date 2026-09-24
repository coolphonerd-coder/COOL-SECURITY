-- COOL SECURITY: ejecuta este archivo completo en Supabase > SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.products (id text primary key,name text not null,category text not null,description text not null default '',image text not null default '',price numeric(12,2) not null check(price>=0),stock integer not null default 0 check(stock>=0),active boolean not null default true,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.orders (id uuid primary key default gen_random_uuid(),order_number text unique not null,customer_name text not null,customer_phone text not null,customer_address text not null,customer_city text not null,delivery text not null,payment text not null,source text not null default 'Tienda online',status text not null default 'Nuevo' check(status in('Nuevo','Confirmado','Cancelado','Entregado')),total numeric(12,2) not null check(total>=0),created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.order_items (id bigint generated always as identity primary key,order_id uuid not null references public.orders(id) on delete cascade,product_id text not null references public.products(id),product_name text not null,price numeric(12,2) not null check(price>=0),quantity integer not null check(quantity>0));
alter table public.products enable row level security; alter table public.orders enable row level security; alter table public.order_items enable row level security;
drop policy if exists "Public can view active products" on public.products; create policy "Public can view active products" on public.products for select to anon,authenticated using(active=true or auth.role()='authenticated');
drop policy if exists "Admins manage products" on public.products; create policy "Admins manage products" on public.products for all to authenticated using(true) with check(true);
drop policy if exists "Public creates orders" on public.orders;
drop policy if exists "Admins view orders" on public.orders; create policy "Admins view orders" on public.orders for select to authenticated using(true);
drop policy if exists "Admins update orders" on public.orders; create policy "Admins update orders" on public.orders for update to authenticated using(true) with check(true);
drop policy if exists "Public creates order items" on public.order_items;
drop policy if exists "Admins view order items" on public.order_items; create policy "Admins view order items" on public.order_items for select to authenticated using(true);
insert into public.products(id,name,category,price,stock,image,description) values
('cam-dual-8k','Cámara Dual Híbrida WiFi 8K','Cámaras',5966,12,'assets/gallery/proyecto-14.jpg','Vigilancia inteligente, visión nocturna y acceso remoto.'),
('kit-cam-2','Kit de 2 Cámaras Dual 8K','Kits',11932,8,'assets/gallery/proyecto-08.jpg','Kit híbrido WiFi listo para instalación profesional.'),('kit-cam-4','Kit de 4 Cámaras de Seguridad','Kits',21900,6,'assets/gallery/proyecto-05.jpg','Sistema completo para hogar, comercio u oficina.'),('dvr-16','DVR Híbrido 16 Canales 4K','Cámaras',11200,5,'assets/gallery/proyecto-10.jpg','Grabador multiformato de alta resolución y acceso remoto.'),('starlink-mini','Starlink Mini V4','Starlink',16900,7,'assets/gallery/proyecto-18.jpg','Internet satelital compacto para hogar, negocio o movilidad.'),('router-starlink','Router Starlink','Starlink',3500,14,'assets/gallery/proyecto-16.jpg','Amplía y mejora la cobertura de tu red Starlink.'),('cable-starlink','Cable Starlink','Starlink',5900,9,'assets/gallery/proyecto-19.jpg','Cable de reemplazo compatible para instalaciones Starlink.'),('base-starlink','Base para Antena Starlink','Starlink',5500,11,'assets/gallery/proyecto-15.jpg','Base resistente para una instalación estable y segura.'),('repetidor-7dbi','Repetidor WiFi Turbo 7dBi','Redes',2600,18,'assets/gallery/proyecto-13.jpg','Mayor alcance y estabilidad para hogares y negocios.'),('utp-500','Cable UTP Certificado 500 pies','Redes',6500,10,'assets/gallery/proyecto-06.jpg','Cable exterior categoría 5E para redes y videovigilancia.'),('panel-solar','Panel Solar para Cámara','Energía',3220,15,'assets/gallery/proyecto-11.jpg','Alimentación solar continua para cámaras compatibles.'),('control-acceso','Control de Acceso Inteligente','Acceso',8900,4,'assets/gallery/proyecto-04.jpg','Control seguro mediante código, tarjeta o acceso inteligente.') on conflict(id) do update set name=excluded.name,category=excluded.category,price=excluded.price,image=excluded.image,description=excluded.description;
do $$ begin alter publication supabase_realtime add table public.orders; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.products; exception when duplicate_object then null; end $$;

create or replace function public.create_store_order(p_customer_name text,p_customer_phone text,p_customer_address text,p_customer_city text,p_delivery text,p_payment text,p_items jsonb)
returns text language plpgsql security definer set search_path=public as $$
declare v_order_id uuid; v_number text; v_total numeric(12,2):=0; v_item jsonb; v_product products%rowtype; v_qty integer;
begin
  if jsonb_array_length(p_items)=0 then raise exception 'El pedido está vacío'; end if;
  v_number:='CS-'||right((extract(epoch from clock_timestamp())*1000)::bigint::text,8);
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty:=greatest(1,least(99,(v_item->>'quantity')::integer));
    select * into v_product from products where id=v_item->>'product_id' and active=true;
    if not found or v_product.stock<v_qty then raise exception 'Producto agotado o cantidad no disponible'; end if;
    v_total:=v_total+(v_product.price*v_qty);
  end loop;
  insert into orders(order_number,customer_name,customer_phone,customer_address,customer_city,delivery,payment,total) values(v_number,trim(p_customer_name),trim(p_customer_phone),trim(p_customer_address),trim(p_customer_city),p_delivery,p_payment,v_total) returning id into v_order_id;
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty:=greatest(1,least(99,(v_item->>'quantity')::integer)); select * into v_product from products where id=v_item->>'product_id';
    insert into order_items(order_id,product_id,product_name,price,quantity) values(v_order_id,v_product.id,v_product.name,v_product.price,v_qty);
  end loop;
  return v_number;
end $$;
revoke all on function public.create_store_order(text,text,text,text,text,text,jsonb) from public;
grant execute on function public.create_store_order(text,text,text,text,text,text,jsonb) to anon,authenticated;

create or replace function public.confirm_store_order(p_order_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_status text; v_item order_items%rowtype;
begin
  if auth.role()<>'authenticated' then raise exception 'Acceso no autorizado'; end if;
  select status into v_status from orders where id=p_order_id for update;
  if v_status is null then raise exception 'Pedido no encontrado'; end if;
  if v_status<>'Nuevo' then return; end if;
  for v_item in select * from order_items where order_id=p_order_id loop
    update products set stock=greatest(0,stock-v_item.quantity),updated_at=now() where id=v_item.product_id;
  end loop;
  update orders set status='Confirmado',updated_at=now() where id=p_order_id;
end $$;
revoke all on function public.confirm_store_order(uuid) from public;
grant execute on function public.confirm_store_order(uuid) to authenticated;
